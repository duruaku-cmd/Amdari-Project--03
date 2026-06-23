"""SentinelPay Payments API — main entrypoint."""
import os
import logging
from flask import Flask, jsonify

from app.routes.auth import auth_bp
from app.routes.accounts import accounts_bp
from app.routes.transactions import transactions_bp
from app.routes.wallets import wallets_bp
from app.routes.webhooks import webhooks_bp
from app.routes.admin import admin_bp


def create_app():
    app = Flask(__name__)
    app.config["ENVIRONMENT"] = os.environ.get("ENVIRONMENT", "production")

    app.register_blueprint(auth_bp, url_prefix="/v1/auth")
    app.register_blueprint(accounts_bp, url_prefix="/v1/accounts")
    app.register_blueprint(transactions_bp, url_prefix="/v1/transactions")
    app.register_blueprint(wallets_bp, url_prefix="/v1/wallets")
    app.register_blueprint(webhooks_bp, url_prefix="/v1/webhooks")
    app.register_blueprint(admin_bp, url_prefix="/v1/admin")

    @app.route("/health")
    def health():
        return jsonify({"status": "ok", "service": "payments-api"})

    @app.errorhandler(Exception)
    def handle_exception(e):
        """V-APP-09 FIX: never leak stack traces or exception detail to clients.
        The full error is logged server-side; the client gets a generic message
        and a correlation id."""
        import uuid
        correlation_id = uuid.uuid4().hex
        logging.getLogger("sentinelpay.error").exception(
            "unhandled error correlation_id=%s", correlation_id)
        return jsonify({"error": "internal server error",
                        "correlation_id": correlation_id}), 500

    return app


if __name__ == "__main__":
    app = create_app()
    # V-APP-09 FIX: debug mode is OFF. Host/port unchanged.
    app.run(host="0.0.0.0", port=8001, debug=False)
