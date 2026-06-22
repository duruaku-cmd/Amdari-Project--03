"""Identity verification endpoints."""
import os
import requests
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth

verify_bp = Blueprint("verify", __name__)

BVN_LOOKUP_URL = os.environ.get("BVN_LOOKUP_URL", "https://api.mock-cbn.local/bvn")


@verify_bp.route("/bvn", methods=["POST"])
@require_auth
def verify_bvn():
    """Verify a BVN against the upstream lookup service.

    NOTE: the SSRF in this endpoint (V-APP-04 — caller controls `provider`) is
    INTENTIONALLY NOT fixed today. Day 5 is scoped to the four critical-path
    items (SQLi, JWT, IDOR, race). SSRF is remediated on Day 6. Left as-is so the
    Day 5 commit set stays clean.
    """
    data = request.get_json() or {}
    bvn = data.get("bvn")
    provider_url = data.get("provider", BVN_LOOKUP_URL)

    if not bvn or len(bvn) != 11:
        return jsonify({"error": "valid 11-digit BVN required"}), 400

    try:
        resp = requests.post(provider_url, json={"bvn": bvn}, timeout=10)
        return jsonify({"status": "ok", "provider_response": resp.text[:2000]})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@verify_bp.route("/lookup", methods=["GET"])
@require_auth
def lookup_kyc():
    """Look up a KYC record by BVN or NIN.

    V-APP-01 FIX: bvn/nin are now bound parameters, not concatenated into the
    SQL. A single parameterised statement is used; the column to filter on is
    chosen by safe server-side branching, never from user text.
    """
    bvn = request.args.get("bvn", "")
    nin = request.args.get("nin", "")

    conn = get_connection()
    cur = conn.cursor()
    try:
        if bvn:
            cur.execute("SELECT * FROM kyc_records WHERE bvn = %s", (bvn,))
        elif nin:
            cur.execute("SELECT * FROM kyc_records WHERE nin = %s", (nin,))
        else:
            return jsonify({"error": "bvn or nin required"}), 400

        records = cur.fetchall()
        return jsonify([dict(r) for r in records])
    finally:
        cur.close()
        conn.close()
