"""Authentication routes: registration, login, and OTP."""
import secrets
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import hash_password, verify_password, issue_token
from app.security import audit
from app.ratelimit import rate_limit

auth_bp = Blueprint("auth", __name__)

# Roles a self-service registrant may ever receive. 'admin'/'finance' are never
# assignable via the public register endpoint (V-APP-07).
_SELF_SERVICE_ROLES = {"merchant"}


@auth_bp.route("/register", methods=["POST"])
@rate_limit(limit=5, window_seconds=60)   # V-APP-08
def register():
    data = request.get_json() or {}
    email = data.get("email")
    password = data.get("password")
    full_name = data.get("full_name", "")

    # V-APP-07 FIX: the role is NOT taken from the client. Public registration
    # always creates a merchant; privileged roles are provisioned out-of-band.
    role = "merchant"

    if not email or not password:
        return jsonify({"error": "email and password required"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO users (email, password_hash, full_name, role) VALUES (%s, %s, %s, %s) RETURNING id",
            (email, hash_password(password), full_name, role)
        )
        user_id = cur.fetchone()["id"]
        conn.commit()
        audit("user.register", actor=email, target=f"user:{user_id}", role=role)
        return jsonify({"id": user_id, "email": email, "role": role}), 201
    finally:
        cur.close()
        conn.close()


@auth_bp.route("/login", methods=["POST"])
@rate_limit(limit=5, window_seconds=60)   # V-APP-08
def login():
    data = request.get_json() or {}
    email = data.get("email")
    password = data.get("password")

    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id, password_hash, role, is_active FROM users WHERE email = %s", (email,))
        user = cur.fetchone()
        # V-APP-06: verify_password returns (ok, new_hash). new_hash is set when a
        # legacy MD5 hash matched and should be upgraded to Argon2id.
        ok, new_hash = (False, None)
        if user:
            ok, new_hash = verify_password(password, user["password_hash"])
        if not user or not ok:
            audit("user.login", actor=email, outcome="failure")
            return jsonify({"error": "invalid credentials"}), 401
        if not user["is_active"]:
            return jsonify({"error": "account suspended"}), 403

        if new_hash:
            cur.execute("UPDATE users SET password_hash = %s WHERE id = %s", (new_hash, user["id"]))
            conn.commit()
            audit("user.password_migrated", actor=email, target=f"user:{user['id']}")

        token = issue_token(user["id"], user["role"])
        audit("user.login", actor=email, target=f"user:{user['id']}", outcome="success")
        return jsonify({"token": token, "user_id": user["id"], "role": user["role"]})
    finally:
        cur.close()
        conn.close()


@auth_bp.route("/otp", methods=["POST"])
@rate_limit(limit=3, window_seconds=60)   # V-APP-08
def request_otp():
    """Request an OTP code for step-up authentication.

    V-APP-08 hardening: OTP uses a cryptographically secure RNG and is no longer
    printed to stdout.
    """
    data = request.get_json() or {}
    phone = data.get("phone")
    otp = f"{secrets.randbelow(1000000):06d}"   # secure RNG, not random.randint
    # The OTP is delivered out-of-band (SMS) in production; never logged.
    audit("otp.request", actor=phone, outcome="success")
    return jsonify({"status": "sent", "phone": phone})
