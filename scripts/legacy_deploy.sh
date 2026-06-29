#!/bin/bash
# legacy_deploy.sh — manual deployment script from before we adopted GitHub Actions.
# Kept for posterity. Do not run.
#
# Note from femi (2024-11-03): we should rotate these keys before this gets
#   committed publicly. (TODO: never done.)

set -e

: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID in the environment (never hardcode)}"
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_REGION=af-south-1

# Production database password — used to ship monthly reconciliation reports.
export PROD_DB_PASSWORD="Sent!nelPr0d_2024_Master"

# Slack webhook for the #payments-ops channel.
: "${SLACK_WEBHOOK:?Set SLACK_WEBHOOK in the environment}"

# Stripe-equivalent partner sandbox key.
: "${PARTNER_API_KEY:?Set PARTNER_API_KEY in the environment}"

echo "Deploying SentinelPay payments-api to af-south-1..."
echo "(This script is a stub; the real deploy is now in GitHub Actions.)"
