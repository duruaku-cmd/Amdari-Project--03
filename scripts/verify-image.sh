#!/usr/bin/env bash
# =============================================================================
#  verify-image.sh  —  D-07 signature & SBOM verification (FAILS CLOSED)
#  Verifies that an image was signed by OUR GitHub Actions identity via Cosign
#  keyless, and that a signed SBOM is attached. Exits non-zero on ANY failure:
#  missing signature, wrong identity, tampered image, or missing SBOM.
#
#  Usage: ./verify-image.sh <image_ref>
#  Requires: cosign installed; network access to Rekor/Fulcio.
# =============================================================================
set -euo pipefail

IMAGE="${1:?Usage: verify-image.sh <image_ref>}"

# The identity we REQUIRE the signature to come from. A signature from any other
# identity (e.g. an attacker's) fails verification. Scope to this repo + workflow.
EXPECTED_IDENTITY_REGEX="^https://github.com/duruaku-cmd/Amdari-Project--03/.github/workflows/.+@refs/heads/main$"
EXPECTED_OIDC_ISSUER="https://token.actions.githubusercontent.com"

echo "==> Verifying image signature for: $IMAGE"

# 1) Verify the image signature, pinned to our identity + issuer.
if ! cosign verify \
      --certificate-identity-regexp "$EXPECTED_IDENTITY_REGEX" \
      --certificate-oidc-issuer "$EXPECTED_OIDC_ISSUER" \
      "$IMAGE" >/dev/null 2>&1; then
  echo "::error::SIGNATURE VERIFICATION FAILED for $IMAGE."
  echo "         The image is unsigned, tampered, or signed by an unexpected identity."
  echo "         FAILING CLOSED — deployment blocked."
  exit 1
fi
echo "    [OK] Image signature valid and from the expected identity."

# 2) Verify a signed SBOM attestation is attached.
echo "==> Verifying attached SBOM signature"
if ! cosign verify \
      --certificate-identity-regexp "$EXPECTED_IDENTITY_REGEX" \
      --certificate-oidc-issuer "$EXPECTED_OIDC_ISSUER" \
      --attachment sbom \
      "$IMAGE" >/dev/null 2>&1; then
  echo "::error::SBOM signature verification FAILED — no signed SBOM attached."
  echo "         FAILING CLOSED — deployment blocked."
  exit 1
fi
echo "    [OK] Signed SBOM present and valid."

echo "==> SUCCESS: $IMAGE is signed, untampered, and has a signed SBOM. Safe to deploy."
exit 0
