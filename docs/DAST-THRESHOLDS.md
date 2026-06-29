# DAST Gate — Tuned Thresholds (OWASP ZAP)

The ephemeral DAST gate runs OWASP ZAP against a freshly-built, disposable
instance of the SentinelPay application (built from `services/<service>`, with
Postgres + Redis from `docker-compose.yml`). The environment exists only for the
duration of the job and is destroyed in an `always()` teardown step.

## Blocking model

The gate's pass/fail decision has two layers:

1. **`.zap/rules.tsv`** tunes individual ZAP alerts to `FAIL`, `WARN`, or `IGNORE`.
2. **The evaluation step** fails the gate on any alert at ZAP **risk level High**.

This mirrors the "tuned, not silenced" principle used for Semgrep, Bandit, and
Trivy: the threshold is explicit, documented, and auditable — not a blanket
`soft_fail`.

## Why these settings

| Class | Alerts | Rationale |
| --- | --- | --- |
| **FAIL** | SQLi, XSS (reflected/persistent), SSCI, OS command injection, CRLF, RFI, cloud-metadata SSRF | These are the runtime manifestations of SentinelPay's V-APP findings. They are exploitable and must never reach production — so they block the PR. |
| **WARN** | Missing security headers (CSP, X-Frame-Options, X-Content-Type-Options, HSTS), cache-control, X-Powered-By leakage, suspicious comments | Real hardening, tracked and reported, but not gate-blocking in the ephemeral lab: in production these headers are added at the ALB/edge, and TLS (HSTS) is terminated at the ALB, not the app container. |
| **IGNORE** | Cacheable-content, timestamp-disclosure false positives | Not applicable to a stateless API; timestamp disclosure mis-fires on numeric IDs. |

## Evidence

Every run uploads the full ZAP report (`zap-report.html` + `zap-report.json`) as a
build artifact (`zap-dast-report`, 30-day retention). This is the D-08 DAST
evidence: it shows exactly what was scanned, what was found, and how the threshold
was applied.

## Ephemeral-environment rationale

A permanent staging server would cost money, drift from production, and present its
own attack surface. Building the environment per-PR and destroying it guarantees the
scan runs against the exact code in the PR, with no persistent footprint. This is
the modern, cost-correct pattern the brief's "ephemeral DAST" objective calls for.
