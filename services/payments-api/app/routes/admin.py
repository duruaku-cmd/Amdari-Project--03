"""Internal admin endpoints."""
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth
from app.security import load_session, audit

admin_bp = Blueprint("admin", __name__)


def _require_admin():
    return getattr(request, "current_user_role", None) == "admin"


@admin_bp.route("/session/restore", methods=["POST"])
@require_auth
def restore_session():
    """Restore an admin session from a signed-JSON blob.

    V-APP-10 FIX: the previous implementation ran pickle.loads on caller input,
    which executes arbitrary code. Sessions are now signed JSON (data, not code):
    load_session verifies an HMAC signature and JSON-decodes — it can never
    execute code, and a tampered/unsigned blob is rejected.
    """
    if not _require_admin():
        return jsonify({"error": "admin only"}), 403

    data = request.get_json() or {}
    blob = data.get("session")
    if not blob:
        return jsonify({"error": "session blob required"}), 400

    try:
        session = load_session(blob)
    except ValueError:
        audit("admin.session_restore", actor=request.current_user_id, outcome="rejected")
        return jsonify({"error": "invalid or unsigned session"}), 400

    audit("admin.session_restore", actor=request.current_user_id, outcome="success")
    return jsonify({"restored": True, "session_keys": list(session.keys())})


@admin_bp.route("/users", methods=["GET"])
@require_auth
def list_users():
    if not _require_admin():
        return jsonify({"error": "admin only"}), 403
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id, email, full_name, role, is_active, created_at FROM users")
        return jsonify([dict(r) for r in cur.fetchall()])
    finally:
        cur.close()
        conn.close()
