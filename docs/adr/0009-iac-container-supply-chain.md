# ADR 0009 — IaC/Container Gates & Supply-Chain Integrity (Day 17)

- **Status:** Accepted
- **Date:** 2026-06-29
- **Sprint/Day:** Week 3, Day 17 — IaC & Container Gates
- **Author:** Emmanuel Duruaku

## Context

The pipeline enforced code gates (Day 16) but not infrastructure or supply-chain
integrity. Three pipeline/cloud concerns remained: insecure Terraform could merge;
container images were pushed unsigned (V-PIP-01) with no bill of materials
(V-PIP-02); and nothing verified image provenance before deploy.

## Decision

1. **IaC scanning — Checkov + tfsec + OPA.** Checkov and tfsec give broad generic
   AWS misconfiguration coverage; the Day-13 OPA pack enforces the
   SentinelPay-specific baseline. All three run as blocking checks. Checkov skips
   are explicit and justified in `.checkov.yaml`.
2. **Container scanning — Trivy on the built image.** Extends Day-16 dependency
   scanning to the full image filesystem (OS + app). Blocks CRITICAL/HIGH fixable.
3. **SBOM — Syft (CycloneDX).** Generated for every build and uploaded as an
   artefact; closes V-PIP-02 and provides the "what is in production" record.
4. **Signing — Cosign keyless.** Images and SBOMs are signed using the workflow's
   GitHub OIDC identity via Fulcio + Rekor; no long-lived signing key. Closes
   V-PIP-01.
5. **Verification fails closed — `scripts/verify-image.sh`.** Pins the expected
   identity and OIDC issuer; exits non-zero on unsigned, tampered, wrong-identity,
   or missing-SBOM. Produces D-07.

## Why keyless over key-based signing

A long-lived Cosign private key is itself a high-value secret that can leak.
Keyless signing binds each signature to a short-lived, OIDC-derived certificate
and a public transparency-log entry, removing the key-management burden and the
key-theft risk entirely — consistent with the engagement's no-long-lived-keys
posture (the same reasoning as OIDC for AWS deploys).

## Consequences

- **Positive:** insecure infrastructure cannot merge; every image is scanned,
  itemised (SBOM), and signed; deployment verifies provenance and fails closed on
  tampering. Closes V-PIP-01 and V-PIP-02.
- **Trade-off:** signing attests provenance, not innocence — a compromised build
  produces a validly-signed bad image. Mitigated by the other gates + branch
  protection. Documented in D07-SBOM-SIGNATURE-EVIDENCE.md.

## Maps to

- Fills the Day-15 iac-scan stub; adds the supply-chain stage.
- Closes V-PIP-01 (unsigned images) and V-PIP-02 (no SBOM); supports OBJ-05/06.
