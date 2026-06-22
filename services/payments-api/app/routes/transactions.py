"""Transaction search and listing endpoints."""
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth

transactions_bp = Blueprint("transactions", __name__)


@transactions_bp.route("/search", methods=["GET"])
@require_auth
def search_transactions():
    """Search transactions by reference, counterparty, or description.

    V-APP-01 FIX: every user-supplied value is now passed as a bound parameter
    (%s), never concatenated into the SQL text. The database driver keeps data
    and code strictly separate, so payloads like  ' OR '1'='1  are treated as a
    literal search string, not as SQL.
    """
    q = request.args.get("q", "")
    account_id = request.args.get("account_id", "")

    conn = get_connection()
    cur = conn.cursor()
    try:
        # Sink 1 (the `q` LIKE search): pass the wildcard pattern as a parameter.
        like_pattern = f"%{q}%"
        sql = (
            "SELECT id, account_id, reference, amount, currency, direction, "
            "counterparty, description, status, created_at "
            "FROM transactions "
            "WHERE (reference LIKE %s OR counterparty LIKE %s OR description LIKE %s)"
        )
        params = [like_pattern, like_pattern, like_pattern]

        # Sink 2 (the easy-to-miss `account_id`): bound parameter, and validated
        # as an integer so a non-numeric value is rejected rather than injected.
        if account_id:
            try:
                account_id_int = int(account_id)
            except (TypeError, ValueError):
                return jsonify({"error": "account_id must be an integer"}), 400
            sql += " AND account_id = %s"
            params.append(account_id_int)

        sql += " ORDER BY created_at DESC LIMIT 50"

        cur.execute(sql, params)
        rows = cur.fetchall()
        return jsonify([dict(r) for r in rows])
    finally:
        cur.close()
        conn.close()


@transactions_bp.route("/<reference>", methods=["GET"])
@require_auth
def get_transaction(reference):
    """Fetch a single transaction by reference. (Already parameterised.)"""
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT * FROM transactions WHERE reference = %s",
            (reference,)
        )
        txn = cur.fetchone()
        if not txn:
            return jsonify({"error": "transaction not found"}), 404
        return jsonify(dict(txn))
    finally:
        cur.close()
        conn.close()

