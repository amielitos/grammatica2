"""
Idempotency Store for Grammatica Backend.

Provides thread-safe in-memory and persistent on-disk storage for Idempotency-Key records,
handling locking (PENDING), cached response replaying (RESOLVED), request payload fingerprinting
(SHA-256), and TTL-based expiration.
"""

import os
import time
import json
import base64
import hashlib
import asyncio
from typing import Optional, Dict, Tuple, Any
from dataclasses import dataclass, asdict


@dataclass
class IdempotencyRecord:
    key: str
    request_hash: str
    status: str  # "PENDING" | "RESOLVED" | "FAILED"
    status_code: int = 200
    headers: Dict[str, str] = None
    body_base64: str = ""
    created_at: float = 0.0
    expires_at: float = 0.0

    def __post_init__(self):
        if self.headers is None:
            self.headers = {}
        if self.created_at == 0.0:
            self.created_at = time.time()

    @property
    def body_bytes(self) -> bytes:
        if not self.body_base64:
            return b""
        try:
            return base64.b64decode(self.body_base64)
        except Exception:
            return b""

    @body_bytes.setter
    def body_bytes(self, data: bytes):
        self.body_base64 = base64.b64encode(data).decode("ascii")


class IdempotencyStore:
    """
    Manages idempotency tokens, atomic state transitions, and persistent caching.
    """

    def __init__(self, cache_dir: Optional[str] = None, default_ttl_seconds: int = 86400):
        self._records: Dict[str, IdempotencyRecord] = {}
        self._lock = asyncio.Lock()
        self.default_ttl = default_ttl_seconds

        # Persistent storage directory
        if cache_dir is None:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            cache_dir = os.path.join(base_dir, ".idempotency_cache")
        self.cache_dir = cache_dir
        os.makedirs(self.cache_dir, exist_ok=True)

        self._load_from_disk()

    @staticmethod
    def compute_request_hash(method: str, path: str, body: bytes) -> str:
        """Computes a deterministic SHA-256 fingerprint for the request."""
        hasher = hashlib.sha256()
        hasher.update(method.upper().encode("utf-8"))
        hasher.update(b":")
        hasher.update(path.strip().encode("utf-8"))
        hasher.update(b":")
        hasher.update(body)
        return hasher.hexdigest()

    def _file_path_for_key(self, key: str) -> str:
        # Sanitize key for filesystem safety
        safe_key = hashlib.sha256(key.encode("utf-8")).hexdigest()
        return os.path.join(self.cache_dir, f"{safe_key}.json")

    def _load_from_disk(self):
        """Loads non-expired records from disk on startup."""
        now = time.time()
        try:
            for fname in os.listdir(self.cache_dir):
                if fname.endswith(".json"):
                    fpath = os.path.join(self.cache_dir, fname)
                    try:
                        with open(fpath, "r", encoding="utf-8") as f:
                            data = json.load(f)
                            record = IdempotencyRecord(**data)
                            if record.expires_at > now and record.status == "RESOLVED":
                                self._records[record.key] = record
                            elif record.expires_at <= now:
                                os.remove(fpath)
                    except Exception:
                        pass
        except Exception:
            pass

    def _persist_to_disk(self, record: IdempotencyRecord):
        """Saves a resolved record to disk for durability across reloads."""
        if record.status != "RESOLVED":
            return
        fpath = self._file_path_for_key(record.key)
        try:
            with open(fpath, "w", encoding="utf-8") as f:
                json.dump(asdict(record), f, ensure_ascii=False)
        except Exception:
            pass

    def _remove_from_disk(self, key: str):
        fpath = self._file_path_for_key(key)
        if os.path.exists(fpath):
            try:
                os.remove(fpath)
            except Exception:
                pass

    async def acquire(
        self,
        key: str,
        request_hash: str,
        ttl_seconds: Optional[int] = None,
    ) -> Tuple[str, Optional[IdempotencyRecord]]:
        """
        Attempts to acquire the idempotency key lock.

        Returns:
            ("ACQUIRED", None) -> Caller should proceed with request execution.
            ("REPLAY", record) -> Request already completed; caller should replay record.
            ("MISMATCH", record) -> Key was reused with a different payload (RFC violation).
            ("IN_PROGRESS", None) -> Another identical request is currently processing (409 Conflict).
        """
        ttl = ttl_seconds if ttl_seconds is not None else self.default_ttl
        now = time.time()

        async with self._lock:
            # Clean up if expired
            existing = self._records.get(key)
            if existing and existing.expires_at <= now:
                del self._records[key]
                self._remove_from_disk(key)
                existing = None

            if existing is None:
                # Fresh key: register as PENDING
                record = IdempotencyRecord(
                    key=key,
                    request_hash=request_hash,
                    status="PENDING",
                    created_at=now,
                    expires_at=now + ttl,
                )
                self._records[key] = record
                return "ACQUIRED", None

            # Key exists: check fingerprint
            if existing.request_hash != request_hash:
                return "MISMATCH", existing

            # Check status
            if existing.status == "PENDING":
                # Check for stale lock (timeout after 120 seconds if worker crashed)
                if (now - existing.created_at) > 120:
                    existing.status = "PENDING"
                    existing.created_at = now
                    existing.expires_at = now + ttl
                    return "ACQUIRED", None
                return "IN_PROGRESS", None

            if existing.status == "RESOLVED":
                return "REPLAY", existing

            # If previous failed, allow re-acquisition
            existing.status = "PENDING"
            existing.created_at = now
            existing.expires_at = now + ttl
            return "ACQUIRED", None

    async def complete(
        self,
        key: str,
        status_code: int,
        headers: Dict[str, str],
        body: bytes,
    ):
        """Marks the idempotency key as RESOLVED and caches the response."""
        now = time.time()
        async with self._lock:
            record = self._records.get(key)
            if record:
                record.status = "RESOLVED"
                record.status_code = status_code
                record.headers = {
                    k: v for k, v in headers.items()
                    if k.lower() not in {"content-length", "connection", "transfer-encoding"}
                }
                record.body_bytes = body
                self._persist_to_disk(record)

    async def release(self, key: str, failed: bool = True):
        """Releases the lock on failure so subsequent attempts can retry."""
        async with self._lock:
            if key in self._records:
                if failed:
                    del self._records[key]
                    self._remove_from_disk(key)
                else:
                    self._records[key].status = "FAILED"

    async def get(self, key: str) -> Optional[IdempotencyRecord]:
        async with self._lock:
            return self._records.get(key)


# Global singleton instance
idempotency_store = IdempotencyStore()
