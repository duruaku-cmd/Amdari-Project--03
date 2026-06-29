# SAST & Secret-Scanning Baseline

This baseline records the expected clean state of the hardened repository so that
*new* findings introduced by a PR are distinguishable from pre-existing accepted
state.

- **Gitleaks:** 0 secrets in the current tree and history (the Week-2 secret
  migration to Secrets Manager + OIDC removed all hardcoded credentials).
- **Semgrep (custom SentinelPay rules):** 0 ERROR findings against the patched
  codebase. The same rules produce 3 ERROR findings against the *unpatched* Week-1
  code (SQLi, broken JWT, command injection) — proving the rules would have caught
  the original vulnerabilities.
- **Bandit:** 0 HIGH findings against the patched codebase.
- **Trivy (deps):** 0 CRITICAL/HIGH fixable findings at baseline.

Any deviation above threshold on a PR is a regression and blocks merge.

## Accepted SAST exceptions (reviewed)

- **Bandit B324 — security.py (legacy MD5 verify):** accepted via scoped
  `# nosec B324` + `usedforsecurity=False`. The MD5 call verifies an existing
  legacy hash during password migration and immediately upgrades the password to
  Argon2; MD5 is never used to store a new password. The exception is scoped to
  the single reviewed line; all other MD5 usage still blocks.
