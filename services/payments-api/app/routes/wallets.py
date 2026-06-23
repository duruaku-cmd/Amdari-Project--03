"""Wallet credit and debit operations."""
import uuid
from decimal import Decimal
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth
from app.security import audit

wallets_bp = Blueprint("wallets", __name__)


def _owns_or_admin(cur, account_id):
    if getattr(request, "current_user_role", None) == "admin":
        return True
    cur.execute("SELECT user_id FROM accounts WHERE id = %s", (account_id,))
    row = cur.fetchone()
    return bool(row) and row["user_id"] == request.current_user_id


@wallets_bp.route("/<int:account_id>/credit", methods=["POST"])
@require_auth
def credit_wallet(account_id):
    """Credit funds to a wallet. (V-APP-03 ownership + atomic from Day 5;
    V-APP-11 audit logging added Day 6.)"""
    data = request.get_json() or {}
    amount = Decimal(str(data.get("amount", "0")))
    description = data.get("description", "credit")
    if amount <= 0:
        return jsonify({"error": "amount must be positive"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        if not _owns_or_admin(cur, account_id):
            return jsonify({"error": "account not found"}), 404

        cur.execute(
            "UPDATE accounts SET balance = balance + %s WHERE id = %s RETURNING balance",
            (amount, account_id))
        row = cur.fetchone()
        if not row:
            conn.rollback()
            return jsonify({"error": "account not found"}), 404
        new_balance = Decimal(str(row["balance"]))

        reference = f"TXN-{uuid.uuid4().hex[:12].upper()}"
        cur.execute(
            "INSERT INTO transactions (account_id, reference, amount, direction, description, status) "
            "VALUES (%s, %s, %s, 'credit', %s, 'completed')",
            (account_id, reference, amount, description))
        conn.commit()
        audit("wallet.credit", actor=request.current_user_id,
              target=f"account:{account_id}", outcome="success",
              amount=str(amount), reference=reference, new_balance=str(new_balance))
        return jsonify({"reference": reference, "new_balance": str(new_balance)})
    finally:
        cur.close()
        conn.close()


@wallets_bp.route("/<int:account_id>/debit", methods=["POST"])
@require_auth
def debit_wallet(account_id):
    """Debit funds from a wallet. (V-APP-05 atomic race fix + V-APP-03 ownership
    from Day 5; V-APP-11 audit logging added Day 6.)"""
    data = request.get_json() or {}
    amount = Decimal(str(data.get("amount", "0")))
    counterparty = data.get("counterparty", "")
    description = data.get("description", "debit")
    if amount <= 0:
        return jsonify({"error": "amount must be positive"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        if not _owns_or_admin(cur, account_id):
            return jsonify({"error": "account not found"}), 404

        cur.execute(
            "UPDATE accounts SET balance = balance - %s "
            "WHERE id = %s AND balance >= %s RETURNING balance",
            (amount, account_id, amount))
        row = cur.fetchone()
        if not row:
            cur.execute("SELECT 1 FROM accounts WHERE id = %s", (account_id,))
            exists = cur.fetchone()
            conn.rollback()
            if not exists:
                return jsonify({"error": "account not found"}), 404
            audit("wallet.debit", actor=request.current_user_id,
                  target=f"account:{account_id}", outcome="declined",
                  amount=str(amount), reason="insufficient_funds")
            return jsonify({"error": "insufficient funds"}), 400

        new_balance = Decimal(str(row["balance"]))
        reference = f"TXN-{uuid.uuid4().hex[:12].upper()}"
        cur.execute(
            "INSERT INTO transactions (account_id, reference, amount, direction, counterparty, description, status) "
            "VALUES (%s, %s, %s, 'debit', %s, %s, 'completed')",
            (account_id, reference, amount, counterparty, description))
        conn.commit()
        audit("wallet.debit", actor=request.current_user_id,
              target=f"account:{account_id}", outcome="success",
              amount=str(amount), reference=reference, new_balance=str(new_balance))
        return jsonify({"reference": reference, "new_balance": str(new_balance)})
    finally:
        cur.close()
        conn.close()
