"""
Email sending route for Grammatica backend.
"""

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from middleware.auth import verify_api_key

router = APIRouter(prefix="/api/v1/email", tags=["Email"])


class EmailRequest(BaseModel):
    recipientEmail: EmailStr
    subject: str
    body: str


@router.post("/send", dependencies=[Depends(verify_api_key)])
async def send_email(request: EmailRequest):
    """
    Send an HTML email securely from the backend without exposing SMTP credentials in the mobile app.
    """
    smtp_email = os.getenv("SMTP_EMAIL", "")
    smtp_password = os.getenv("SMTP_PASSWORD", "")
    smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))

    if not smtp_email or not smtp_password:
        raise HTTPException(
            status_code=500,
            detail="SMTP credentials are not configured on the server."
        )

    try:
        msg = MIMEMultipart("alternative")
        msg["From"] = f"Grammatica Team <{smtp_email}>"
        msg["To"] = request.recipientEmail
        msg["Subject"] = request.subject

        part = MIMEText(request.body, "html")
        msg.attach(part)

        server = smtplib.SMTP(smtp_host, smtp_port)
        server.starttls()
        server.login(smtp_email, smtp_password)
        server.sendmail(smtp_email, request.recipientEmail, msg.as_string())
        server.quit()

        return {"status": "success", "message": f"Email successfully sent to {request.recipientEmail}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send email: {str(e)}")
