# ADR-0010: Ephemeral DAST with OWASP ZAP

## Status
Accepted (Day 18)

## Context
The pipeline must enforce DAST as a blocking gate against "the deployed staging
environment" (brief, OBJ-05). Options for the environment: (a) a permanent staging
deployment, (b) a full ECS Fargate spin-up/tear-down per PR, (c) a containerised
app stood up inside the runner.

## Decision
Use option (c): an ephemeral environment built per-PR from the repo's
`docker-compose.yml` (app + Postgres + Redis), scanned with OWASP ZAP, then
destroyed in an `always()` teardown. ZAP findings are evaluated against a tuned
`.zap/rules.tsv` and a High-risk blocking threshold.

## Rationale
- Scans the REAL application over HTTP (true DAST), finding runtime issues SAST
  cannot — exactly the V-APP class (injection, headers, SSRF).
- No AWS cost or Free-Tier quota risk; no persistent staging attack surface.
- The environment matches the PR's exact code; no drift.
- The same job can later target the published ECR image for a prod-replica scan.

## Consequences
- Adds ~3-5 min to the pipeline per PR (build + scan + teardown).
- Requires Docker-in-runner (standard on GitHub-hosted runners).
- The blocking threshold and alert tuning are documented in DAST-THRESHOLDS.md and
  must be reviewed via the same exception process as the other gates.
