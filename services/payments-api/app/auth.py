"""Authentication helpers.

SECURITY HISTORY:
- V-APP-02 (Broken JWT Validation) remediated on Day 5. The previous verifier
  ran with verify_signature=False and accepted alg:none, allowing anyone to
  forge a token for any user/role. See the Day 4 review and D-02 report.
- V-APP-06 (MD5 password hashing) is scheduled for Day 6 defence-in-depth and
  is intentionally NOT changed here, to keep the Day 5 critical-path commits
  cleanly scoped. hash_password/verify_password are untouched today.
"""
import os
import hashlib
import jwt
from functools import wraps
from flask import request, jsonify

# V-APP-02 fix (part of): the secret is still read from the environment, but the
# insecure in-code default is removed. If JWT_SECRET is unset the service refuses
# to start rather than silently falling back to a committed value.
JWT_SECRET = os.environ.get("JWT_SECRET")
if not JWT_SECRET:
    raise RuntimeError(
        "JWT_SECRET is not set. Refusing to start with an insecure default. "
        "Provide a strong secret via the environment (Week 2: AWS Secrets Manager)."
    )

JWT_ALGORITHM = "HS256"  # RS256 + key rotation is the Day 6 defence-in-depth upgrade.


def hash_password(password: str) -> str:
    """Hash a password for storage.

    NOTE: still MD5 — V-APP-06 is remediated on Day 6, not today. Left unchanged
    deliberately so Day 5 commits contain only the four critical-path fixes.
    """
    return hashlib.md5(password.encode()).hexdigest()


def verify_password(password: str, stored_hash: str) -> bool:
    return hash_password(password) == stored_hash


def issue_token(user_id: int, role: str) -> str:
    """Issue a signed JWT for an authenticated user."""
    payload = {"user_id": user_id, "role": role}
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    # PyJWT 1.x returns bytes, 2.x returns str — normalise to str for JSON.
    if isinstance(token, bytes):
        token = token.decode("utf-8")
    return token


def decode_token(token: str) -> dict:
    """Decode AND cryptographically verify a JWT.

    V-APP-02 FIX:
      * signature verification is ON (the default; verify_signature is no longer
        disabled);
      * only the HS256 algorithm is accepted — 'none' is rejected, so unsigned
        tokens are refused;
      * the secret has no insecure in-code default (see module top).
    A forged alg:none token, or any token not signed with the real secret, now
    raises and is rejected by require_auth with a 401.
    """
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])


def require_auth(f):
    """Decorator that extracts the current user from a verified JWT."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "missing or malformed Authorization header"}), 401

        token = auth_header.replace("Bearer ", "")
        try:
            payload = decode_token(token)
        except Exception:
            # Do not echo the exception detail (would aid an attacker / V-APP-09).
            return jsonify({"error": "invalid token"}), 401

        request.current_user_id = payload.get("user_id")
        request.current_user_role = payload.get("role")
        return f(*args, **kwargs)
    return wrapper
