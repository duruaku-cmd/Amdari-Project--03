"""Account lookup and listing endpoints."""
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth

accounts_bp = Blueprint("accounts", __name__)


def _is_admin():
    """Admins may legitimately access any account."""
    return getattr(request, "current_user_role", None) == "admin"


@accounts_bp.route("/<int:account_id>", methods=["GET"])
@require_auth
def get_account(account_id):
    """Look up an account by ID.

    V-APP-03 FIX (the originating incident): the query now enforces ownership.
    A non-admin caller can only read an account whose user_id matches their own;
    requesting someone else's account returns 404 (we deliberately do not
    distinguish 'not found' from 'not yours', to avoid leaking existence).
    Admins retain full access.
    """
    conn = get_connection()
    cur = conn.cursor()
    try:
        if _is_admin():
            cur.execute(
                "SELECT id, user_id, account_number, currency, balance, status, created_at "
                "FROM accounts WHERE id = %s",
                (account_id,)
            )
        else:
            cur.execute(
                "SELECT id, user_id, account_number, currency, balance, status, created_at "
                "FROM accounts WHERE id = %s AND user_id = %s",
                (account_id, request.current_user_id)
            )
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
    """List accounts belonging to the current user. (Already correctly scoped.)"""
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT id, account_number, currency, balance, status FROM accounts WHERE user_id = %s",
            (request.current_user_id,)
        )
        rows = cur.fetchall()
        return jsonify([dict(r) for r in rows])
    finally:
        cur.close()
        conn.close()


@accounts_bp.route("/<int:account_id>/profile", methods=["PUT"])
@require_auth
def update_profile(account_id):
    """Update account profile fields.

    NOTE: the mass-assignment flaw here (V-APP-07) is remediated on Day 6, not
    today. It is INTENTIONALLY left unchanged to keep Day 5 scoped to the four
    critical-path items. (Day 6 will add an allowlist of editable fields AND an
    ownership check on this route.)
    """
    data = request.get_json() or {}
    conn = get_connection()
    cur = conn.cursor()
    try:
        if not data:
            return jsonify({"error": "no fields supplied"}), 400

        set_clause = ", ".join([f"{k} = %s" for k in data.keys()])
        values = list(data.values()) + [account_id]
        cur.execute(f"UPDATE accounts SET {set_clause} WHERE id = %s RETURNING *", values)
        updated = cur.fetchone()
        conn.commit()
        return jsonify(dict(updated))
    finally:
        cur.close()
        conn.close()
