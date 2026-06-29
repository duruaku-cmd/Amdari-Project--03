# SentinelPay OPA Policy Pack (D-05)

Custom Rego policies that block insecure Terraform **before** it merges or
deploys. They run against the JSON output of `terraform plan`, so a pull request
that introduces a public bucket, a world-open security group, an unencrypted
data store, or an IAM god-policy fails the check and cannot merge.

## Policies

| File | Principle enforced | Defends |
| --- | --- | --- |
| `policy/s3_public.rego` | No public S3 (public-access block fully on; no public ACL) | V-CLD-03 |
| `policy/sg_ingress.rego` | No 0.0.0.0/0 ingress except ALB on 80/443 | V-CLD-01 / C-05 |
| `policy/encryption.rego` | Encryption at rest mandatory (RDS, S3, ElastiCache) | V-CLD-02 |
| `policy/iam_wildcard.rego` | No `Action:"*"` on `Resource:"*"` in customer-managed policies | brief hard rule |

Each policy emits a failure message that names the offending resource and the
violated principle.

## Install conftest (one binary)

Windows (PowerShell):
```powershell
winget install OpenPolicyAgent.Conftest
# or download from https://github.com/open-policy-agent/conftest/releases
```

## Run the policies against a real plan

From the `infra/` directory:
```powershell
terraform plan -out tfplan.binary
terraform show -json tfplan.binary > ..\policy\plan.json
cd ..\policy
conftest test --policy policy plan.json
```
A clean plan prints no failures. A plan with a violation prints the failure
message and exits non-zero (which blocks a merge in CI).

## Run the unit tests

```powershell
conftest verify --policy policy
```
All tests should pass. The tests prove each policy both catches violations and
accepts compliant configuration.

## Try the demo fixtures

```powershell
conftest test --policy policy fixtures/bad_plan.json   # should FAIL with 4 messages
conftest test --policy policy fixtures/good_plan.json  # should PASS
```

## Performance

The pack evaluates the full SentinelPay plan in well under 60 seconds (it is
pure policy evaluation over JSON — typically sub-second). It is designed to run
as a blocking pre-merge gate, wired into the Week 3 pipeline (Day 17).

## Exceptions

There is intentionally no inline bypass. A genuine exception requires a
documented, time-boxed waiver reviewed by a second engineer — see the exception
process in the Week 2 report. A developer cannot silently disable a policy.
