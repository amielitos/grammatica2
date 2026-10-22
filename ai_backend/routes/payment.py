"""
PayMongo payment link generation route for Grammatica backend.
"""

import os
import base64
import httpx
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from middleware.auth import verify_api_key

router = APIRouter(prefix="/api/v1/payment", tags=["Payment"])

DEFAULT_SECRET_KEY = "sk_live_spqXAkVZE4LvX2qhKtAR9Nw9"


class PaymentLinkRequest(BaseModel):
    amount: float
    description: str
    remarks: str = "Grammatica Subscription"


def get_auth_header() -> str:
    secret_key = os.getenv("PAYMONGO_SECRET_KEY", "").strip() or DEFAULT_SECRET_KEY
    return f"Basic {base64.b64encode(f'{secret_key}:'.encode()).decode()}"


@router.post("/create-link", dependencies=[Depends(verify_api_key)])
async def create_payment_link(request: PaymentLinkRequest):
    """
    Creates a PayMongo payment link securely from the server side.
    """
    amount_in_cents = int(request.amount * 100)
    auth_header = get_auth_header()

    payload = {
        "data": {
            "attributes": {
                "amount": amount_in_cents,
                "description": request.description,
                "remarks": request.remarks
            }
        }
    }

    async with httpx.AsyncClient() as client:
        try:
            res = await client.post(
                "https://api.paymongo.com/v1/links",
                headers={
                    "accept": "application/json",
                    "content-type": "application/json",
                    "authorization": auth_header
                },
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
                }
            else:
                raise HTTPException(
                    status_code=res.status_code,
                    detail=f"PayMongo error: {res.text}"
                )
        except HTTPException:
            raise
        except Exception as e:
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
