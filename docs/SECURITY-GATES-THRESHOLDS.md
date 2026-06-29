# SentinelPay Pipeline — Security Gate Thresholds (D-06)

A passing pipeline does **not** mean zero findings. It means **zero findings above
the documented threshold**. Each gate's threshold below is an explicit, tuned risk
decision. Every gate also **fails closed**: a tool crash, timeout, or non-finding
error blocks the merge just as a real finding does.

## Day 16 — Code & Dependency Gates

| Gate | Tool | Blocking threshold | Reported (non-blocking) | Why tuned here |
| --- | --- | --- | --- | --- |
| Secret scanning | Gitleaks | **Any** detected secret | — | Secrets are zero-tolerance: a single leaked credential is a breach. No noise problem because the allowlist removes known test/doc values. |
| SAST (patterns) | Semgrep | **ERROR** severity | WARNING, INFO | ERROR maps to exploitable bug classes (SQLi, broken JWT, command injection). WARNING (e.g. SSRF heuristics) needs human triage, so it informs rather than blocks. |
| SAST (Python) | Bandit | **HIGH** severity | MEDIUM, LOW | HIGH = high-confidence, high-impact. MEDIUM/LOW are frequently context-dependent in Flask apps and would generate merge-blocking noise. |
| SCA (deps) | Trivy | **CRITICAL, HIGH** with a fix available | MEDIUM, LOW; any unfixed | Block what is both serious and actionable. `ignore-unfixed` avoids blocking on CVEs the team cannot remediate (no upstream patch yet); those are tracked, not gated. |

## Rationale for "tuned, not zero"

A gate that blocks on *every* finding trains developers to disable it. By blocking
on **High/Critical and exploitable classes** while **reporting** the rest, the
pipeline stays trustworthy and merges stay unblocked for noise. The threshold is a
documented decision, reviewable like any other code, and revisited if the finding
mix changes.

## Exceptions

There is no inline bypass. A genuine exception (e.g. an unfixable transitive CVE
with a compensating control) is recorded as a time-boxed, peer-reviewed waiver in
the PR, naming the finding, the justification, and an expiry date. This mirrors the
OPA-policy exception process and directly answers the brief's exception question.

## Carried forward

- **Day 17:** IaC scan (Checkov/tfsec) blocks on HIGH+; OPA policy gate blocks on any
  deny; Trivy image scan blocks on CRITICAL/HIGH; Cosign signing is mandatory.
- **Day 18:** ZAP DAST baseline blocks on the documented alert threshold.

## Day 17 — IaC, Container & Supply-Chain Gates

| Gate | Tool | Blocking threshold | Why tuned here |
| --- | --- | --- | --- |
| IaC (generic) | Checkov | Any finding not in the documented skip list | Broad AWS misconfig coverage; skips are explicit and justified in `.checkov.yaml`. |
| IaC (generic) | tfsec | Any finding | Complements Checkov; different rule engine catches different issues. |
| IaC (custom) | OPA/conftest | Any `deny` | The SentinelPay baseline is non-negotiable (no public S3, no open ingress, encryption, no IAM wildcards). |
| Container image | Trivy (image) | CRITICAL/HIGH with a fix | Same tuning as dependency scan; covers base-image layers. |
| Image signing | Cosign keyless | Unsigned = block at verify | Signing is mandatory; `verify-image.sh` fails closed. |
| SBOM | Syft (CycloneDX) | Missing SBOM = block at verify | Every image must carry a signed bill of materials. |
