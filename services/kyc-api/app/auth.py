"""Auth helpers for kyc-api.

V-APP-02 (Broken JWT Validation) remediated on Day 5 — identical fix to
payments-api. The two services still duplicate this module (known tech debt);
consolidating into a shared library is noted for later. For now BOTH copies are
fixed, because fixing only one leaves the other service forgeable.
"""
import os
import jwt
from functools import wraps
from flask import request, jsonify

JWT_SECRET = os.environ.get("JWT_SECRET")
if not JWT_SECRET:
    raise RuntimeError(
        "JWT_SECRET is not set. Refusing to start with an insecure default."
    )

JWT_ALGORITHM = "HS256"


def decode_token(token: str) -> dict:
    """Decode AND verify a JWT. V-APP-02 fix: verification on, only HS256, no
    'none', no insecure default secret."""
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])


def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "unauthorized"}), 401
        try:
            payload = decode_token(auth.replace("Bearer ", ""))
        except Exception:
            return jsonify({"error": "unauthorized"}), 401
        request.current_user_id = payload.get("user_id")
        request.current_user_role = payload.get("role")
        return f(*args, **kwargs)
    return wrapper
