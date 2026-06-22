"""Wallet credit and debit operations."""
import uuid
from decimal import Decimal
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth

wallets_bp = Blueprint("wallets", __name__)


def _owns_or_admin(cur, account_id):
    """Return True if the current user owns account_id, or is an admin.

    V-APP-03 helper for the money-movement paths. Looks up the account's owner
    and compares against the authenticated user. Admins are allowed through.
    """
    if getattr(request, "current_user_role", None) == "admin":
        return True
    cur.execute("SELECT user_id FROM accounts WHERE id = %s", (account_id,))
    row = cur.fetchone()
    return bool(row) and row["user_id"] == request.current_user_id


@wallets_bp.route("/<int:account_id>/credit", methods=["POST"])
@require_auth
def credit_wallet(account_id):
    """Credit funds to a wallet (e.g. inbound transfer settlement).

    V-APP-03 FIX: ownership is enforced before any money moves.
    """
    data = request.get_json() or {}
    amount = Decimal(str(data.get("amount", "0")))
    description = data.get("description", "credit")

    if amount <= 0:
        return jsonify({"error": "amount must be positive"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        if not _owns_or_admin(cur, account_id):
            # 404 rather than 403: do not reveal whether the account exists.
            return jsonify({"error": "account not found"}), 404

        # Atomic credit in a single statement; RETURNING gives us the new balance.
        cur.execute(
            "UPDATE accounts SET balance = balance + %s WHERE id = %s RETURNING balance",
            (amount, account_id)
        )
        row = cur.fetchone()
        if not row:
            conn.rollback()
            return jsonify({"error": "account not found"}), 404
        new_balance = Decimal(str(row["balance"]))

        reference = f"TXN-{uuid.uuid4().hex[:12].upper()}"
        cur.execute(
            "INSERT INTO transactions (account_id, reference, amount, direction, description, status) "
            "VALUES (%s, %s, %s, 'credit', %s, 'completed')",
            (account_id, reference, amount, description)
        )
        conn.commit()
        return jsonify({"reference": reference, "new_balance": str(new_balance)})
    finally:
        cur.close()
        conn.close()


@wallets_bp.route("/<int:account_id>/debit", methods=["POST"])
@require_auth
def debit_wallet(account_id):
    """Debit funds from a wallet.

    V-APP-05 FIX (race condition): the debit is now a single atomic, conditional
    UPDATE:
          UPDATE accounts SET balance = balance - %s
          WHERE id = %s AND balance >= %s
    The database evaluates the balance check and the write as one indivisible
    operation, so two concurrent debits can no longer both observe the same
    pre-balance. If the row was not updated, the funds were insufficient (or the
    account does not exist) and we report that — exactly one of two racing
    debits can succeed.

    V-APP-03 FIX: ownership is enforced before the debit.
    """
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

        # Atomic check-and-debit. Either the row matches (sufficient funds) and is
        # updated, or it does not and zero rows change.
        cur.execute(
            "UPDATE accounts SET balance = balance - %s "
            "WHERE id = %s AND balance >= %s "
            "RETURNING balance",
            (amount, account_id, amount)
        )
        row = cur.fetchone()
        if not row:
            # Distinguish 'no such account' from 'insufficient funds' without an
            # extra unlocked read: re-check existence cheaply.
            cur.execute("SELECT 1 FROM accounts WHERE id = %s", (account_id,))
            exists = cur.fetchone()
            conn.rollback()
            if not exists:
                return jsonify({"error": "account not found"}), 404
            return jsonify({"error": "insufficient funds"}), 400

        new_balance = Decimal(str(row["balance"]))
        reference = f"TXN-{uuid.uuid4().hex[:12].upper()}"
        cur.execute(
            "INSERT INTO transactions (account_id, reference, amount, direction, counterparty, description, status) "
            "VALUES (%s, %s, %s, 'debit', %s, %s, 'completed')",
            (account_id, reference, amount, counterparty, description)
        )
        conn.commit()
        return jsonify({"reference": reference, "new_balance": str(new_balance)})
    finally:
        cur.close()
        conn.close()
