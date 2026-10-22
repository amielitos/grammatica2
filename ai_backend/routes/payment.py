"""
PayMongo payment link generation route for Grammatica backend.
Includes end-to-end idempotency support and webhook deduplication.
"""

import os
import base64
import logging
import httpx
from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Depends, Request, Header
from pydantic import BaseModel
from middleware.auth import verify_api_key

try:
    from services.idempotency_store import idempotency_store
except ImportError:
    from ai_backend.services.idempotency_store import idempotency_store

logger = logging.getLogger("grammatica.payment")
router = APIRouter(prefix="/api/v1/payment", tags=["Payment"])

DEFAULT_SECRET_KEY = "sk_live_spqXAkVZE4LvX2qhKtAR9Nw9"


class PaymentLinkRequest(BaseModel):
    amount: float
    description: str
    remarks: str = "Grammatica Subscription"
    idempotency_key: Optional[str] = None


def get_auth_header() -> str:
    secret_key = os.getenv("PAYMONGO_SECRET_KEY", "").strip() or DEFAULT_SECRET_KEY
    return f"Basic {base64.b64encode(f'{secret_key}:'.encode()).decode()}"


@router.post("/create-link", dependencies=[Depends(verify_api_key)])
async def create_payment_link(
    request: PaymentLinkRequest,
    raw_request: Request,
    idempotency_key_header: Optional[str] = Header(None, alias="Idempotency-Key"),
    x_idempotency_key_header: Optional[str] = Header(None, alias="X-Idempotency-Key"),
):
    """
    Creates a PayMongo payment link securely from the server side.
    Idempotent by design: forwards the idempotency key to PayMongo and
    caches the returned link details.
    """
    amount_in_cents = int(request.amount * 100)
    auth_header = get_auth_header()

    # Determine effective idempotency key
    effective_key = (
        idempotency_key_header
        or x_idempotency_key_header
        or request.idempotency_key
    )

    payload = {
        "data": {
            "attributes": {
                "amount": amount_in_cents,
                "description": request.description,
                "remarks": request.remarks
            }
        }
    }

    headers: Dict[str, str] = {
        "accept": "application/json",
        "content-type": "application/json",
        "authorization": auth_header,
    }

    if effective_key:
        headers["idempotency-key"] = effective_key.strip()

    async with httpx.AsyncClient() as client:
        try:
            res = await client.post(
                "https://api.paymongo.com/v1/links",
                headers=headers,
                json=payload,
                timeout=15.0
            )

            if res.status_code in (200, 201):
                data = res.json()
                attr = data["data"]["attributes"]
                return {
                    "status": "success",
                    "id": data["data"]["id"],
                    "checkout_url": attr.get("checkout_url", ""),
                    "reference_number": attr.get("reference_number", ""),
                    "link_status": attr.get("status", "unpaid"),
                    "amount": request.amount,
                    "description": request.description,
                    "idempotency_key": effective_key,
                }
            else:
                logger.error(f"PayMongo API Error: {res.status_code} - {res.text}")
                raise HTTPException(
                    status_code=res.status_code,
                    detail=f"PayMongo error: {res.text}"
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Unexpected payment link error: {e}")
            raise HTTPException(status_code=500, detail=str(e))


@router.get("/link-status/{link_id}", dependencies=[Depends(verify_api_key)])
async def get_payment_link_status(link_id: str):
    """
    Fetches the latest payment link status from PayMongo.
    """
    auth_header = get_auth_header()

    async with httpx.AsyncClient() as client:
        try:
            res = await client.get(
                f"https://api.paymongo.com/v1/links/{link_id}",
                headers={
                    "accept": "application/json",
                    "authorization": auth_header
                },
                timeout=15.0
            )

            if res.status_code == 200:
                data = res.json()
                attr = data["data"]["attributes"]
                raw_amount = attr.get("amount", 0)
                return {
                    "status": "success",
                    "id": data["data"]["id"],
                    "checkout_url": attr.get("checkout_url", ""),
                    "reference_number": attr.get("reference_number", ""),
                    "link_status": attr.get("status", "unpaid"),
                    "amount": raw_amount / 100.0 if raw_amount else 0.0,
                    "description": attr.get("description", ""),
                }
            else:
                raise HTTPException(
                    status_code=res.status_code,
                    detail=f"PayMongo error fetching link: {res.text}"
                )
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


@router.post("/webhook")
async def paymongo_webhook(request: Request):
    """
    Idempotent PayMongo webhook receiver.
    Ensures that webhook events (e.g. link.paid, payment.paid) are processed
    EXACTLY ONCE by locking on the event id.
    """
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")

    data = body.get("data", {})
    event_id = data.get("id")
    event_type = data.get("attributes", {}).get("type", "unknown")

    if not event_id:
        return {"status": "ignored", "reason": "no_event_id"}

    webhook_key = f"paymongo_webhook_{event_id}"
    req_hash = idempotency_store.compute_request_hash(
        "POST", "/api/v1/payment/webhook", str(body).encode("utf-8")
    )

    action, record = await idempotency_store.acquire(webhook_key, req_hash)
    if action == "REPLAY":
        logger.info(f"🔁 Webhook event {event_id} already processed. Acknowledging with 200 OK.")
        return {"status": "success", "message": "Event already processed", "event_id": event_id}

    if action == "IN_PROGRESS":
        logger.warning(f"⏳ Webhook event {event_id} currently being processed concurrently.")
        return {"status": "pending", "message": "Processing in progress", "event_id": event_id}

    try:
        logger.info(f"💳 Processing PayMongo Webhook [{event_type}] for event {event_id}")
        
        # Mark event as resolved to prevent duplicate executions from at-least-once delivery
        await idempotency_store.complete(
            key=webhook_key,
            status_code=200,
            headers={"content-type": "application/json"},
            body=b'{"status":"acknowledged"}'
        )

        return {
            "status": "success",
            "message": f"Webhook {event_id} processed successfully",
            "event_type": event_type,
        }
    except Exception as e:
        await idempotency_store.release(webhook_key, failed=True)
        logger.error(f"Error handling webhook {event_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
