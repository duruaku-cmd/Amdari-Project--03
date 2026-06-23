"""Identity verification endpoints."""
import os
import requests
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth
from app.security import validate_outbound_url, UnsafeURLError, audit

verify_bp = Blueprint("verify", __name__)

BVN_LOOKUP_URL = os.environ.get("BVN_LOOKUP_URL", "https://api.mock-cbn.local/bvn")
# V-APP-04: only these provider hosts may be contacted for BVN verification.
_ALLOWED_PROVIDER_HOSTS = set(
    h.strip() for h in os.environ.get("BVN_PROVIDER_ALLOWLIST", "").split(",") if h.strip()
)


@verify_bp.route("/bvn", methods=["POST"])
@require_auth
def verify_bvn():
    """Verify a BVN against the upstream lookup service.

    V-APP-04 FIX: the provider URL is validated (http/https, public IP only, no
    metadata/loopback/private hosts) and, if an allowlist is configured, must be
    in it. Redirects are disabled.
    """
    data = request.get_json() or {}
    bvn = data.get("bvn")
    provider_url = data.get("provider", BVN_LOOKUP_URL)

    if not bvn or len(bvn) != 11:
        return jsonify({"error": "valid 11-digit BVN required"}), 400

    try:
        validate_outbound_url(
            provider_url,
            allowed_hosts=_ALLOWED_PROVIDER_HOSTS or None)
    except UnsafeURLError as e:
        audit("kyc.bvn_verify", actor=request.current_user_id, target=provider_url,
              outcome="blocked", reason=str(e))
        return jsonify({"error": f"refused to contact provider: {e}"}), 400

    try:
        resp = requests.post(provider_url, json={"bvn": bvn}, timeout=10, allow_redirects=False)
        return jsonify({"status": "ok", "provider_response": resp.text[:2000]})
    except Exception:
        return jsonify({"error": "provider request failed"}), 502


@verify_bp.route("/lookup", methods=["GET"])
@require_auth
def lookup_kyc():
    """Look up a KYC record by BVN or NIN. (V-APP-01 parameterised — Day 5.)"""
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
        return jsonify([dict(r) for r in cur.fetchall()])
    finally:
        cur.close()
        conn.close()
