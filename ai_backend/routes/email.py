"""
Email sending route for Grammatica backend.
"""

import os
import smtplib
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from middleware.auth import verify_api_key

router = APIRouter(prefix="/api/v1/email", tags=["Email"])
logger = logging.getLogger(__name__)


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

    print(f"📧 Email request received → To: {request.recipientEmail} | Subject: {request.subject[:50]}")

    if not smtp_email or not smtp_password:
        print("❌ SMTP credentials are MISSING in .env! Set SMTP_EMAIL and SMTP_PASSWORD.")
        raise HTTPException(
            status_code=500,
            detail="SMTP credentials are not configured on the server. Set SMTP_EMAIL and SMTP_PASSWORD in ai_backend/.env"
        )

    print(f"🔌 Connecting to SMTP: {smtp_host}:{smtp_port} as {smtp_email}")

    try:
        msg = MIMEMultipart("alternative")
        msg["From"] = f"Grammatica Team <{smtp_email}>"
        msg["To"] = request.recipientEmail
        msg["Subject"] = request.subject

        part = MIMEText(request.body, "html")
        msg.attach(part)

        server = smtplib.SMTP(smtp_host, smtp_port)
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(smtp_email, smtp_password)
        server.sendmail(smtp_email, request.recipientEmail, msg.as_string())
        server.quit()

        print(f"✅ Email sent successfully to {request.recipientEmail}")
        return {"status": "success", "message": f"Email successfully sent to {request.recipientEmail}"}

    except smtplib.SMTPAuthenticationError as e:
        print(f"❌ SMTP Authentication FAILED! Check your Gmail App Password. Error: {e}")
        raise HTTPException(status_code=500, detail=f"SMTP authentication failed. Make sure you are using a Gmail App Password (not your regular Gmail password). Error: {str(e)}")
    except smtplib.SMTPException as e:
        print(f"❌ SMTP Error: {e}")
        raise HTTPException(status_code=500, detail=f"SMTP error: {str(e)}")
    except Exception as e:
        print(f"❌ Unexpected email error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to send email: {str(e)}")

