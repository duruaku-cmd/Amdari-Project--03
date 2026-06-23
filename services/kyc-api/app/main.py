"""SentinelPay KYC API — identity verification service."""
import os
import logging
import uuid
from flask import Flask, jsonify

from app.routes.verify import verify_bp
from app.routes.documents import documents_bp


def create_app():
    app = Flask(__name__)
    app.config["ENVIRONMENT"] = os.environ.get("ENVIRONMENT", "production")

    app.register_blueprint(verify_bp, url_prefix="/v1/verify")
    app.register_blueprint(documents_bp, url_prefix="/v1/documents")

    @app.route("/health")
    def health():
        return jsonify({"status": "ok", "service": "kyc-api"})

    @app.errorhandler(Exception)
    def handle_exception(e):
        """V-APP-09 FIX: generic error to client, full detail logged server-side."""
        correlation_id = uuid.uuid4().hex
        logging.getLogger("sentinelpay.error").exception(
            "unhandled error correlation_id=%s", correlation_id)
        return jsonify({"error": "internal server error",
                        "correlation_id": correlation_id}), 500

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=8002, debug=False)  # V-APP-09: debug off
