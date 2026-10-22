"""
Idempotency Middleware for Grammatica FastAPI Backend.

Implements IETF / Stripe idempotency semantics:
- Extracts `Idempotency-Key` or `X-Idempotency-Key` from request headers.
- Hashes request method, path, and payload (SHA-256).
- If request is completed: returns cached response with `Idempotent-Replay: true`.
- If request is in-flight: returns 409 Conflict with Retry-After.
- If payload mismatch: returns 422 Unprocessable Entity.
- On 2xx response: caches response atomically for transparent replay.
- On 5xx error: releases lock to allow graceful client retries.
"""

from typing import Callable
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from fastapi.responses import JSONResponse
import logging

try:
    from services.idempotency_store import idempotency_store
except ImportError:
    from ai_backend.services.idempotency_store import idempotency_store

logger = logging.getLogger("grammatica.idempotency")

MUTATING_METHODS = {"POST", "PUT", "PATCH", "DELETE"}


class IdempotencyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Only inspect mutating HTTP methods
        if request.method not in MUTATING_METHODS:
            return await call_next(request)

        # Extract idempotency key from headers (standard or X- prefixed)
        idempotency_key = (
            request.headers.get("Idempotency-Key")
            or request.headers.get("X-Idempotency-Key")
        )

        # If not provided, continue normally
        if not idempotency_key or not idempotency_key.strip():
            return await call_next(request)

        idempotency_key = idempotency_key.strip()

        # Read and buffer request body so it can be hashed and read by routes
        body = await request.body()

        # Re-set receive channel so downstream endpoints (and multipart/JSON parsers) work seamlessly
        async def receive():
            return {"type": "http.request", "body": body, "more_body": False}

        request._receive = receive

        # Compute payload fingerprint
        request_hash = idempotency_store.compute_request_hash(
            request.method, request.url.path, body
        )

        # Attempt to acquire lock or retrieve cached response
        action, record = await idempotency_store.acquire(idempotency_key, request_hash)

        if action == "REPLAY" and record:
            logger.info(f"🔁 Idempotent Replay for key: {idempotency_key} ({request.url.path})")
            headers = dict(record.headers)
            headers["Idempotent-Replay"] = "true"
            headers["X-Idempotency-Key"] = idempotency_key
            return Response(
                content=record.body_bytes,
                status_code=record.status_code,
                headers=headers,
                media_type=headers.get("content-type", "application/json"),
            )

        elif action == "MISMATCH":
            logger.warning(
                f"⚠️ Idempotency Mismatch: Key {idempotency_key} reused with different payload."
            )
            return JSONResponse(
                status_code=422,
                content={
                    "detail": "Idempotency key was previously used with a different request payload.",
                    "idempotency_key": idempotency_key,
                },
            )

        elif action == "IN_PROGRESS":
            logger.warning(
                f"⏳ Idempotency Conflict: Key {idempotency_key} is currently being processed."
            )
            return JSONResponse(
                status_code=409,
                content={
                    "detail": "A request with this idempotency key is currently in progress. Please retry shortly.",
                    "idempotency_key": idempotency_key,
                },
                headers={"Retry-After": "2"},
            )

        # Action is ACQUIRED: Proceed with route execution
        try:
            response = await call_next(request)

            # Buffer response body to cache it
            response_body = b""
            async for chunk in response.body_iterator:
                response_body += chunk if isinstance(chunk, bytes) else chunk.encode("utf-8")

            # Store resolved response if successful (2xx) or deterministic client errors
            if 200 <= response.status_code < 300:
                resp_headers = dict(response.headers)
                await idempotency_store.complete(
                    key=idempotency_key,
                    status_code=response.status_code,
                    headers=resp_headers,
                    body=response_body,
                )

            elif response.status_code >= 500:
                # Server error: release lock so client can retry safely
                await idempotency_store.release(idempotency_key, failed=True)

            # Return reconstructed response
            resp_headers = dict(response.headers)
            resp_headers["X-Idempotency-Key"] = idempotency_key
            return Response(
                content=response_body,
                status_code=response.status_code,
                headers=resp_headers,
                media_type=response.media_type,
            )

        except Exception as e:
            # Release lock on unexpected server crash
            await idempotency_store.release(idempotency_key, failed=True)
            logger.error(f"Error during idempotent request execution: {e}")
            raise
