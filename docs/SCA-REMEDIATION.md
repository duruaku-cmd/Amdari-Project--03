# SCA Gate — Dependency Remediation (Day 17/18)

Trivy's SCA scan flagged 9 HIGH-severity vulnerabilities in each service's
`requirements.txt` (18 total, all with fixed versions available). Unlike a tuned
exception, these were **remediated outright** by upgrading to patched versions —
the correct response when a fix exists.

## Vulnerabilities fixed

| Library | Was | Now | CVE(s) fixed | Impact |
| --- | --- | --- | --- | --- |
| flask | 2.0.1 | 3.0.3 | CVE-2023-30861 | Session-cookie disclosure (missing Vary: Cookie). |
| werkzeug | 2.0.1 | 3.0.3 | CVE-2023-25577, CVE-2024-34069 | Multipart DoS; debugger RCE on a dev machine. |
| gunicorn | 20.1.0 | 22.0.0 | CVE-2024-1135, CVE-2024-6827 | HTTP request smuggling (Transfer-Encoding). |
| pyjwt | 1.7.1 | 2.13.0 | CVE-2022-29217, CVE-2026-32597, CVE-2026-48526 | **JWT auth bypass via forged tokens** — critical for a payments API. |
| redis | 4.3.4 | 4.5.4 | CVE-2023-28859 | Async command information disclosure. |
| requests | 2.25.1 | 2.32.4 | (proactive) CVE-2024-35195 et al. | Session-verify bypass. |
| boto3 | 1.20.0 | 1.34.0 | (proactive currency) | Removes EOL transitive deps. |

## Compatibility verification

- **Flask 2.x → 3.x:** the app uses `Flask()`, blueprints, `jsonify`,
  `errorhandler`, and `route` — all unchanged across the 2→3 boundary. Werkzeug
  3.0.3 is the matched pair for Flask 3.0.3 (clearing CVE-2024-34069 requires
  Werkzeug ≥3.0.3, which requires Flask ≥3.0 — hence the modern pair, not a 2.3.x
  backport that would leave that CVE open).
- **pyjwt 1.x → 2.x:** the 2.x `jwt.decode()` requires an explicit `algorithms=`
  argument. The app **already** passes `algorithms=` (the Week-1 V-APP-02 fix), so
  the major bump is drop-in with no code change.
- **requests 2.32.0 was yanked** from PyPI (CVE-mitigation conflict); pinned to
  2.32.4 instead.
- Full set resolves with no pip dependency conflict (verified).

## Result
SCA gate: **18 HIGH → 0**. This is genuine remediation, not a documented
exception — the strongest possible SCA outcome and a clean before/after for the
report. The JWT auth-bypass fix is the headline: on a payments platform, a forged
-token vulnerability is among the highest-impact issues SCA can surface.
