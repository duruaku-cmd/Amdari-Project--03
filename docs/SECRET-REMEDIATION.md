# Secret-Scanning: Finding, Remediation & Exception Record (V-CLD-04 / C-04)

## What the gate found

On the first pipeline run, the Gitleaks secret-scanning gate scanned 23 commits
of history and **blocked the merge** on 5 hardcoded credentials in the inherited
codebase:

| # | Type | File | Line | Commit |
| --- | --- | --- | --- | --- |
| 1 | AWS access key | docker-compose.yml | 32 | e253f31 |
| 2 | AWS access key | docker-compose.yml | 51 | e253f31 |
| 3 | AWS access key | scripts/legacy_deploy.sh | 10 | d43665a |
| 4 | Stripe API key (PARTNER_API_KEY) | scripts/legacy_deploy.sh | 21 | d43665a |
| 5 | Slack webhook URL | scripts/legacy_deploy.sh | 18 | d43665a |

This is direct, automated evidence of finding V-CLD-04 / C-04 ("hardcoded
long-lived AWS keys in source"). The gate behaved correctly: it failed closed and
blocked the merge.

## Assessment

All five values were assessed and confirmed to be **placeholder / example values**
(e.g. the canonical AWS documentation key `AKIAIOSFODNN7EXAMPLE`). They are not
live credentials and carry no exploitation risk. The problem they represent is the
**insecure pattern** — secrets written into committed files — not an active leak.

## Remediation (proper, not suppression)

1. **Current files fixed.** The literal values were removed from
   `docker-compose.yml` and `scripts/legacy_deploy.sh` and replaced with
   environment-variable references (`${AWS_ACCESS_KEY_ID}` etc.). In the hardened
   deployment these values are never static keys at all: GitHub Actions uses OIDC
   federation (no long-lived keys) and runtime secrets come from AWS Secrets
   Manager (Week 2). `.env` and key files were added to `.gitignore`.
2. **Blocking gate scoped to new commits.** On pull requests the gate scans the
   PR's commits, so **any new secret blocks the merge** while decades of legacy
   history do not re-block every future PR.
3. **Legacy findings documented, not silenced.** The 5 historical findings are
   pinned by exact fingerprint in `.gitleaksignore`, each annotated. This is an
   auditable, reversible exception that names precisely what is exempted and why —
   not a broad allowlist that would blind the scanner to real keys.

## Why history was not rewritten

The values are non-exploitable placeholders, so destructive history rewriting
(git filter-repo / BFG) — which changes every downstream commit hash and breaks
existing clones — was judged disproportionate. Had any secret been a live
credential, the response would instead have been: rotate/revoke the credential
immediately, then rewrite history. This decision is recorded deliberately.

## Why this class won't ship again

A new hardcoded secret in any future PR produces a fingerprint not present in
`.gitleaksignore`, so the gate trips and blocks the merge. The pattern is now
enforced, not merely discouraged.
