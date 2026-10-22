"""
Unit and Integration Tests for Grammatica AI Backend Idempotency System.
"""

import asyncio
import os
import sys

if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from services.idempotency_store import IdempotencyStore, idempotency_store
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient
from middleware.idempotency import IdempotencyMiddleware


def test_idempotency_store_lifecycle():
    store = IdempotencyStore(cache_dir=os.path.join(BASE_DIR, ".test_idempotency_cache"))
    key = "unit_test_key_001"
    req_hash_1 = store.compute_request_hash("POST", "/api/v1/payment/create-link", b'{"amount": 168.0}')
    req_hash_2 = store.compute_request_hash("POST", "/api/v1/payment/create-link", b'{"amount": 392.0}')

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    # 1. Acquire new key
    action, record = loop.run_until_complete(store.acquire(key, req_hash_1))
    assert action == "ACQUIRED"
    assert record is None

    # 2. In-progress check (while PENDING)
    action, record = loop.run_until_complete(store.acquire(key, req_hash_1))
    assert action == "IN_PROGRESS"

    # 3. Complete and cache
    loop.run_until_complete(
        store.complete(
            key=key,
            status_code=201,
            headers={"content-type": "application/json"},
            body=b'{"status": "success", "id": "link_123"}'
        )
    )

    # 4. Replay check with identical payload
    action, record = loop.run_until_complete(store.acquire(key, req_hash_1))
    assert action == "REPLAY"
    assert record is not None
    assert record.status_code == 201
    assert record.body_bytes == b'{"status": "success", "id": "link_123"}'

    # 5. Mismatch check with modified payload
    action, record = loop.run_until_complete(store.acquire(key, req_hash_2))
    assert action == "MISMATCH"

    # 6. Release lock
    loop.run_until_complete(store.release(key, failed=True))
    assert loop.run_until_complete(store.get(key)) is None

    loop.close()
    print("✅ test_idempotency_store_lifecycle passed!")


def test_idempotency_middleware_integration():
    app = FastAPI()
    app.add_middleware(IdempotencyMiddleware)

    counter = {"calls": 0}

    @app.post("/test-mutation")
    async def mutation_endpoint(data: dict):
        counter["calls"] += 1
        return {"action": "processed", "call_number": counter["calls"], "received": data}

    client = TestClient(app)

    # 1. Initial request with Idempotency-Key
    headers = {"Idempotency-Key": "client_key_999"}
    payload = {"account": "learner_1", "tier": "standard"}

    resp1 = client.post("/test-mutation", json=payload, headers=headers)
    assert resp1.status_code == 200
    data1 = resp1.json()
    assert data1["call_number"] == 1
    assert "Idempotent-Replay" not in resp1.headers

    # 2. Duplicate request with identical Idempotency-Key
    resp2 = client.post("/test-mutation", json=payload, headers=headers)
    assert resp2.status_code == 200
    data2 = resp2.json()
    # Call number must be identical (1) because handler was NOT re-executed!
    assert data2["call_number"] == 1
    assert resp2.headers.get("Idempotent-Replay") == "true"
    assert resp2.headers.get("X-Idempotency-Key") == "client_key_999"
    assert counter["calls"] == 1

    # 3. Request with same key but DIFFERENT payload -> 422 Unprocessable Entity
    different_payload = {"account": "learner_1", "tier": "premium"}
    resp3 = client.post("/test-mutation", json=different_payload, headers=headers)
    assert resp3.status_code == 422
    assert "different request payload" in resp3.json()["detail"]

    print("✅ test_idempotency_middleware_integration passed!")


if __name__ == "__main__":
    test_idempotency_store_lifecycle()
    test_idempotency_middleware_integration()
    print("🎉 ALL IDEMPOTENCY BACKEND TESTS PASSED!")
