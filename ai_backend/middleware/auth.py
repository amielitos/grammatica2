"""
API Key authentication middleware.

All incoming requests to /api/* must include a valid `X-API-Key` header.
"""

from fastapi import Request, HTTPException, Security
from fastapi.security import APIKeyHeader
from config import settings

API_KEY_HEADER = APIKeyHeader(name="X-API-Key", auto_error=False)


async def verify_api_key(api_key: str = Security(API_KEY_HEADER)):
    """
    Dependency that verifies the X-API-Key header matches the configured secret.
    Raises 401 if missing, 403 if invalid.
    """
    if api_key is None:
        raise HTTPException(
            status_code=401,
            detail="Missing API key. Include 'X-API-Key' header in your request.",
        )
    if api_key != settings.API_SECRET_KEY:
        raise HTTPException(
            status_code=403,
            detail="Invalid API key.",
        )
    return api_key
