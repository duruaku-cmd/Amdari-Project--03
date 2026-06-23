"""Lightweight per-client rate limiting (V-APP-08).

In-memory sliding-window limiter keyed by client IP + endpoint. This is a
dependency-free baseline suitable for a single instance; the production design
moves the counter into Redis (already provisioned in docker-compose) so the
limit holds across multiple instances. That migration is noted for Week 2.
"""
import time
from functools import wraps
from collections import defaultdict, deque
from flask import request, jsonify

_buckets = defaultdict(deque)   # key -> deque[timestamps]


def _client_key(name):
    # X-Forwarded-For aware, falls back to remote_addr.
    fwd = request.headers.get("X-Forwarded-For", "")
    ip = fwd.split(",")[0].strip() if fwd else (request.remote_addr or "unknown")
    return f"{ip}:{name}"


def rate_limit(limit=5, window_seconds=60):
    """Allow at most `limit` requests per `window_seconds` per client+endpoint."""
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            key = _client_key(f.__name__)
            now = time.time()
            bucket = _buckets[key]
            # drop timestamps outside the window
            while bucket and bucket[0] <= now - window_seconds:
                bucket.popleft()
            if len(bucket) >= limit:
                retry = int(window_seconds - (now - bucket[0]))
                resp = jsonify({"error": "rate limit exceeded", "retry_after_seconds": max(retry, 1)})
                resp.status_code = 429
                resp.headers["Retry-After"] = str(max(retry, 1))
                return resp
            bucket.append(now)
            return f(*args, **kwargs)
        return wrapper
    return decorator
