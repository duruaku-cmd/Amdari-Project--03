# ADR 0007 — CI/CD Pipeline Scaffold, Branch Protection & OIDC Trust

- **Status:** Accepted
- **Date:** 2026-06-26
- **Sprint/Day:** Week 3, Day 15 — Pipeline Scaffold
- **Author:** Emmanuel Duruaku

## Context

Weeks 1–2 produced security controls (remediated app code, hardened Terraform,
an OPA policy pack) but nothing enforced them automatically, and there was no
single, governed path to production. The inherited `.github/workflows/ci.yml`
embodied four pipeline findings: unsigned images (V-PIP-01), no SBOM (V-PIP-02),
an AdministratorAccess pipeline principal authenticated with long-lived keys
(V-PIP-03), and an unprotected `main` branch (V-PIP-04).

## Decision

Establish the pipeline foundation that the Day 16–18 gates attach to:

1. **Reusable-workflow skeleton.** `pipeline.yml` orchestrates the pipeline on
   every pull request to `main`, calling one reusable workflow per stage
   (secret-scan, SAST, SCA, IaC+OPA, OIDC verify). Stages are reusable
   workflows, not duplicated YAML, satisfying the D-06 distinction bar.
2. **Fail-closed posture.** A terminal `pipeline-status` job runs `always()` and
   exits non-zero if any upstream job failed, errored, or was cancelled. A tool
   crash blocks the merge; it never silently passes.
3. **Least privilege by default.** The workflow sets `contents: read` globally;
   only the OIDC verify job requests `id-token: write`. No job may write repo
   contents.
4. **Branch protection (V-PIP-04).** `scripts/set-branch-protection.ps1` applies
   required status checks (the pipeline jobs), one required reviewer,
   `enforce_admins`, linear history, and no force-push/deletion to `main`.
   A `CODEOWNERS` file backs required review.
5. **OIDC trust + role audit (V-PIP-03).** `reusable-oidc-verify.yml` assumes the
   Day-9 repo-scoped deploy role via OIDC (short-lived session, no static keys)
   and asserts at runtime that the role carries no AdministratorAccess.
   `scripts/audit-deploy-role.ps1` produces the standing evidence.

## Why a PR-triggered pipeline rather than push-triggered

The insecure baseline ran on push to `main` — i.e. after code had already
landed. Triggering on `pull_request` means every gate runs *before* merge, so
an insecure change is blocked rather than merely reported after the fact. This
is the structural difference between CI that observes and a pipeline that
enforces.

## Consequences

- **Positive:** a single governed deployment path; checks run automatically and
  block on failure; the pipeline principal is provably non-admin and keyless;
  `main` cannot be pushed to directly. The skeleton lets branch-protection
  required-checks be configured now, before the gates are filled in.
- **Trade-off:** placeholder stubs currently pass by design; they must be
  replaced with real gate logic (Days 16–17) before the pipeline provides
  assurance. This is tracked and sequenced, not overlooked.

## Maps to

- V-PIP-03 (pipeline admin) — addressed via scoped OIDC role + runtime assertion.
- V-PIP-04 (no branch protection) — addressed via branch-protection script + CODEOWNERS.
- V-PIP-01 / V-PIP-02 — scaffolded; remediated Days 16–17.
