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


class PaymentLinkRequest(BaseModel):
    amount: float
    description: str
    remarks: str = "Grammatica Subscription"


@router.post("/create-link", dependencies=[Depends(verify_api_key)])
async def create_payment_link(request: PaymentLinkRequest):
    """
    Creates a PayMongo payment link securely from the server side.
    """
    secret_key = os.getenv("PAYMONGO_SECRET_KEY", "")
    if not secret_key:
        raise HTTPException(
            status_code=500,
            detail="PayMongo secret key is not configured on the server."
        )

    amount_in_cents = int(request.amount * 100)
    auth_header = f"Basic {base64.b64encode(f'{secret_key}:'.encode()).decode()}"

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
                checkout_url = data["data"]["attributes"]["checkout_url"]
                return {"status": "success", "checkout_url": checkout_url}
            else:
                raise HTTPException(
                    status_code=res.status_code,
                    detail=f"PayMongo error: {res.text}"
                )
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
