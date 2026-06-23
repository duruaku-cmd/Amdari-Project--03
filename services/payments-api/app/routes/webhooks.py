"""Webhook registration and callback testing."""
import os
import requests
from flask import Blueprint, request, jsonify

from app.db import get_connection
from app.auth import require_auth
from app.security import validate_outbound_url, UnsafeURLError, audit

webhooks_bp = Blueprint("webhooks", __name__)

WEBHOOK_TIMEOUT = int(os.environ.get("WEBHOOK_TIMEOUT", "10"))
MAX_RESPONSE_BYTES = 5000


@webhooks_bp.route("/", methods=["POST"])
@require_auth
def register_webhook():
    """Register a callback URL for transaction events."""
    data = request.get_json() or {}
    callback_url = data.get("callback_url")
    event_type = data.get("event_type", "transaction.completed")

    if not callback_url:
        return jsonify({"error": "callback_url required"}), 400

    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO webhooks (user_id, callback_url, event_type) VALUES (%s, %s, %s) RETURNING id",
            (request.current_user_id, callback_url, event_type)
        )
        webhook_id = cur.fetchone()["id"]
        conn.commit()
        return jsonify({"id": webhook_id, "callback_url": callback_url}), 201
    finally:
        cur.close()
        conn.close()


@webhooks_bp.route("/test", methods=["POST"])
@require_auth
def test_webhook():
    """Test-fire a webhook by fetching the supplied URL.

    V-APP-04 FIX: the URL is validated before any request is made —
      * http/https only;
      * host must resolve only to public IPs (blocks 169.254.169.254 metadata,
        loopback, and RFC1918 private ranges);
      * redirects are disabled (a 30x can't bounce us to a blocked host);
      * the response body is size-capped.
    """
    data = request.get_json() or {}
    url = data.get("url")
    if not url:
        return jsonify({"error": "url required"}), 400

    try:
        validate_outbound_url(url)
    except UnsafeURLError as e:
        audit("webhook.test", actor=request.current_user_id, target=url,
              outcome="blocked", reason=str(e))
        return jsonify({"error": f"refused to fetch URL: {e}"}), 400

    try:
        resp = requests.get(url, timeout=WEBHOOK_TIMEOUT, allow_redirects=False, stream=True)
        body = resp.raw.read(MAX_RESPONSE_BYTES, decode_content=True)
        audit("webhook.test", actor=request.current_user_id, target=url, outcome="success")
        return jsonify({
            "status_code": resp.status_code,
            "body": body.decode("utf-8", errors="replace")
        })
    except Exception:
        return jsonify({"error": "request failed"}), 502
