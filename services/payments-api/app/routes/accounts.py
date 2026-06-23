"""Account lookup and listing endpoints."""
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth
from app.security import audit

accounts_bp = Blueprint("accounts", __name__)

# V-APP-07 FIX: only these columns may be updated via the profile route.
# balance, user_id, status, role, etc. are NEVER client-writable.
_EDITABLE_PROFILE_FIELDS = {"full_name", "email", "phone"}


def _is_admin():
    return getattr(request, "current_user_role", None) == "admin"


@accounts_bp.route("/<int:account_id>", methods=["GET"])
@require_auth
def get_account(account_id):
    """Look up an account by ID. (V-APP-03 ownership fix from Day 5.)"""
    conn = get_connection()
    cur = conn.cursor()
    try:
        if _is_admin():
            cur.execute(
                "SELECT id, user_id, account_number, currency, balance, status, created_at "
                "FROM accounts WHERE id = %s", (account_id,))
        else:
            cur.execute(
                "SELECT id, user_id, account_number, currency, balance, status, created_at "
                "FROM accounts WHERE id = %s AND user_id = %s",
                (account_id, request.current_user_id))
        account = cur.fetchone()
        if not account:
            return jsonify({"error": "account not found"}), 404
        return jsonify(dict(account))
    finally:
        cur.close()
        conn.close()


@accounts_bp.route("/", methods=["GET"])
@require_auth
def list_accounts():
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT id, account_number, currency, balance, status FROM accounts WHERE user_id = %s",
            (request.current_user_id,))
        return jsonify([dict(r) for r in cur.fetchall()])
    finally:
        cur.close()
        conn.close()


@accounts_bp.route("/<int:account_id>/profile", methods=["PUT"])
@require_auth
def update_profile(account_id):
    """Update account profile fields.

    V-APP-07 FIX: only an allowlisted set of profile fields may be written. Any
    attempt to set balance/user_id/status/etc. is rejected. Also adds the
    ownership check this route previously lacked (V-APP-03): a non-admin may only
    edit an account they own.
    """
    data = request.get_json() or {}
    if not data:
        return jsonify({"error": "no fields supplied"}), 400

    # Reject any field not on the allowlist.
    bad = set(data.keys()) - _EDITABLE_PROFILE_FIELDS
    if bad:
        audit("account.profile_update", actor=request.current_user_id,
              target=f"account:{account_id}", outcome="blocked",
              rejected_fields=sorted(bad))
        return jsonify({"error": f"these fields cannot be updated: {sorted(bad)}"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        # Ownership check (V-APP-03) unless admin.
        if not _is_admin():
            cur.execute("SELECT user_id FROM accounts WHERE id = %s", (account_id,))
            row = cur.fetchone()
            if not row or row["user_id"] != request.current_user_id:
                return jsonify({"error": "account not found"}), 404

        set_clause = ", ".join([f"{k} = %s" for k in data.keys()])
        values = list(data.values()) + [account_id]
        cur.execute(f"UPDATE accounts SET {set_clause} WHERE id = %s RETURNING *", values)
        updated = cur.fetchone()
        conn.commit()
        audit("account.profile_update", actor=request.current_user_id,
              target=f"account:{account_id}", outcome="success",
              fields=sorted(data.keys()))
        return jsonify(dict(updated))
    finally:
        cur.close()
        conn.close()
