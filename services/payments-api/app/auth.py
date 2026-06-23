"""Authentication helpers.

SECURITY HISTORY:
- V-APP-02 (Broken JWT) fixed Day 5: verification on, only HS256, no insecure
  default secret. (RS256 + rotation is tracked for Week 2 cloud key management.)
- V-APP-06 (MD5) fixed Day 6: password hashing now delegates to app.security
  (Argon2id) with transparent migrate-on-login for legacy MD5 hashes.
"""
import os
import jwt
from functools import wraps
from flask import request, jsonify

from app.security import hash_password as _hash, verify_password as _verify

JWT_SECRET = os.environ.get("JWT_SECRET")
if not JWT_SECRET:
    raise RuntimeError("JWT_SECRET is not set. Refusing to start with an insecure default.")

JWT_ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    """Argon2id hash (V-APP-06). Delegates to app.security."""
    return _hash(password)


def verify_password(password: str, stored_hash: str):
    """Verify a password. Returns (ok, new_hash_or_None) so callers can migrate
    a legacy MD5 hash to Argon2id on successful login."""
    return _verify(password, stored_hash)


def issue_token(user_id: int, role: str) -> str:
    payload = {"user_id": user_id, "role": role}
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    if isinstance(token, bytes):       # PyJWT 1.x compat
        token = token.decode("utf-8")
    return token


def decode_token(token: str) -> dict:
    """Decode AND verify a JWT (V-APP-02 fix)."""
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])


def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "missing or malformed Authorization header"}), 401
        token = auth_header.replace("Bearer ", "")
        try:
            payload = decode_token(token)
        except Exception:
            return jsonify({"error": "invalid token"}), 401
        request.current_user_id = payload.get("user_id")
        request.current_user_role = payload.get("role")
        return f(*args, **kwargs)
    return wrapper
