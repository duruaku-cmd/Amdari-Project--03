# SentinelPay CI/CD Security Pipeline (Week 3)

The pipeline is the **sole path to production** and enforces security as
**blocking gates** on every pull request to `main`. It is built from reusable
workflows and **fails closed** — any tool error, timeout, or cancellation
blocks the merge.

## Structure

| File | Role |
| --- | --- |
| `pipeline.yml` | Orchestrator. Runs on PR; calls each stage; final fail-closed gate. |
| `reusable-secret-scan.yml` | Secret scanning (Gitleaks) — *Day 16* |
| `reusable-sast.yml` | SAST (Semgrep / Bandit) — *Day 16* |
| `reusable-sca.yml` | Dependency scan / SCA — *Day 16* |
| `reusable-iac-scan.yml` | IaC scan (Checkov / tfsec) + OPA policy gate — *Day 17* |
| `reusable-oidc-verify.yml` | Assume scoped deploy role via OIDC; assert non-admin — *Day 15* |

> Today the scan stages are **scaffold stubs** that succeed and print what they
> will enforce, so branch-protection required-checks can be configured now. The
> real gate logic lands on Days 16–17.

## Pipeline findings addressed

| ID | Finding | How |
| --- | --- | --- |
| V-PIP-03 | Pipeline has admin | OIDC short-lived session to a **scoped** role; runtime assertion it is not AdministratorAccess. |
| V-PIP-04 | No branch protection | `scripts/set-branch-protection.ps1` + `CODEOWNERS`. |
| V-PIP-01 | Unsigned images | Cosign keyless signing — *Day 17*. |
| V-PIP-02 | No SBOM | Syft CycloneDX SBOM — *Day 17*. |

## Set it up

```powershell
# 1. Apply branch protection (needs GitHub CLI: gh auth login)
.\scripts\set-branch-protection.ps1

# 2. Audit the deploy role (V-PIP-03 evidence)
.\scripts\audit-deploy-role.ps1

# 3. Open a test PR — the pipeline runs and all scaffold gates show green.
```

## Why "fail closed"

A pipeline that fails *open* lets code through when a scanner crashes — so an
attacker who can crash a scanner can ship anything. The terminal
`pipeline-status` job enforces the opposite: if any gate did not explicitly
pass, the merge is blocked.
