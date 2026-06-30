# tfsec Exception Register — SentinelPay

tfsec (v1.28.14) reports **26 findings** against `infra/` (6 critical, 7 high,
5 medium, 8 low). Every one was triaged. **None required a Terraform code change** —
they split into three classes, mirroring the Checkov exception register and the OPA
waiver process. Suppression lives in `infra/.tfsec/config.yml`; this file is the
human-readable justification.

> Philosophy: *tuned, not silenced.* Each excluded check is a deliberate risk
> decision, recorded here with a rationale and (where relevant) the production
> hardening it defers.

## Class A — Already fixed in code (static-analysis false positive)

tfsec cannot resolve a `kms_key_id` supplied through a cross-module variable
(`var.kms_key_arn`) or a sibling module's KMS key — the identical limitation that
produced false positives in Checkov. The encryption **is** applied; `terraform plan`
shows the resolved key ARN on every log group.

| Check | Findings | Why it's a false positive |
| --- | --- | --- |
| aws-cloudwatch-log-group-customer-key | #19, #20, #22, #23, #24 | CMK is wired via `var.kms_key_arn` (compute/observability) and `aws_kms_key.network` (network). tfsec sees the variable, not the resolved ARN. |

## Class B — Intentional architecture decisions

| Check | Findings | Decision |
| --- | --- | --- |
| aws-elb-alb-not-public | #7 | The ALB is the platform's single public entry point. Being internet-facing is the design, not a defect. |
| aws-elb-http-not-used | #1 | No ACM cert / domain exists in the Free-Tier lab. HTTPS-only is recorded as a production recommendation; the WAF + listener structure is already in place to add it. |
| aws-ec2-no-public-ingress-sgr | #2, #3 | The ALB security group must accept 80/443 from the internet. App tier is locked down by SG-reference chaining (no public CIDR). |
| aws-ec2-no-public-egress-sgr | #4, #5, #6 | Standard outbound egress. Inbound is the controlled surface and is restricted by SG references. |
| aws-ec2-no-public-ip-subnet | #10, #11 | Public subnets exist specifically to host the ALB and NAT, which require public IPs. Workloads run in private subnets. |
| aws-iam-no-policy-wildcards | #9, #12, #13 | #9/#12: `logs:CreateLogStream` **requires** the `"<logGroupArn>:*"` form — the wildcard is mandatory syntax, scoped to one log group. #13: the containment Lambda's `ec2:CreateTags` uses an explicit, non-wildcard action list; the resource is scoped further in prod. |
| aws-iam-no-user-attached-policies | #26 | The honeytoken **is** a standalone decoy IAM user with a directly-attached deny-all policy. A group would defeat the purpose. |
| aws-s3-encryption-customer-key | #8 | `kyc_logs` is an S3 **log-delivery target**. SSE-KMS on a log-target bucket blocks delivery, so AES256 is correct by design. |
| aws-s3-enable-bucket-logging | #17, #18 | `kyc_logs` / `trail` are themselves the log-target buckets; a log bucket logging to itself is not permitted. |

## Class C — Free-Tier lab deferrals (valid prod hardening)

| Check | Finding | Deferred because | Production action |
| --- | --- | --- | --- |
| aws-rds-specify-backup-retention | #15 | Lab uses `backup_retention_period = 1`. | Set to 30. |
| AVD-AWS-0176 (rds IAM auth) | #14 | Secrets Manager rotation is used for DB creds in the lab. | Enable IAM DB authentication. |
| AVD-AWS-0177 (rds deletion protection) | #16 | Off so the lab stack can be torn down. | Enable deletion protection. |
| aws-rds-enable-performance-insights | #21 | Incurs cost beyond Free Tier. | Enable Performance Insights. |
| aws-lambda-enable-tracing | #25 | X-Ray adds cost/setup. | Enable Active tracing on the containment Lambda. |

### Note on finding IDs #14 and #16
These two surface as **`Rego Package builtin.aws.rds.aws0176 / aws0177`** with no
`aws-…` slug — they are the newer Trivy/AVD rego checks bundled into tfsec. They are
therefore excluded by their **AVD IDs** (`AVD-AWS-0176`, `AVD-AWS-0177`), not an
`aws-` name. (An earlier draft used a non-existent `aws-rds-no-public-db-access`
slug that matched nothing; corrected here.)

## Result
With `infra/.tfsec/config.yml` applied: **26 → 0**. tfsec gate goes green, which
greens `iac-scan`, which finally lets the Ephemeral DAST job run.
