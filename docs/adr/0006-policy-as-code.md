# ADR 0006 — Policy as Code (OPA / Rego) for Terraform

- **Status:** Accepted
- **Date:** 2026-06-25
- **Sprint/Day:** Week 2, Day 13 — Policy as Code
- **Author:** Emmanuel Duruaku

## Context

Days 8–12 built a hardened, deployed environment. Nothing, however, prevents a
future change from re-introducing the very misconfigurations the engagement
exists to eliminate: a public bucket, a world-open security group, an
unencrypted store, or an IAM god-policy. Preventive runtime controls (WAF,
security groups) do not stop insecure infrastructure from being *authored*.
This is Deliverable D-05.

## Decision

Author a custom Open Policy Agent (OPA) **Rego** policy pack, evaluated by
**conftest** against the JSON output of `terraform plan`, enforcing the
SentinelPay baseline:

1. **No public S3** (`s3_public.rego`) — public-access block must be fully on;
   public ACLs forbidden. Defends V-CLD-03.
2. **No 0.0.0.0/0 ingress except ALB 80/443** (`sg_ingress.rego`) — defends
   V-CLD-01 / C-05.
3. **Encryption at rest mandatory** (`encryption.rego`) — RDS, S3, ElastiCache.
   Defends V-CLD-02.
4. **No IAM wildcard-on-wildcard** (`iam_wildcard.rego`) — the brief hard rule.

Each policy emits a failure message naming the offending resource and the
violated principle. The pack ships with conftest unit tests proving each policy
both denies violations and accepts compliant configuration, plus good/bad plan
fixtures for demonstration.

## Why custom Rego in addition to Checkov / tfsec

Checkov and tfsec (added in the Week 3 pipeline, Day 17) provide broad,
generic coverage. The custom Rego pack encodes the *SentinelPay-specific*
baseline — for example, that 0.0.0.0/0 is acceptable on the ALB SG but nowhere
else — which generic rulesets cannot express. The two are complementary:
generic scanners for breadth, custom policy for the rules unique to this estate.

## Integration & exceptions

The pack runs as a blocking pre-merge check on every Terraform PR (wired in
Day 17). It evaluates the full plan in well under the 60-second bar. There is no
inline bypass mechanism: a genuine exception requires a documented, time-boxed
waiver reviewed by a second engineer, so a developer cannot silently disable a
control — directly answering the brief's exception-process question.

## Consequences

- **Positive:** the security baseline becomes self-enforcing; regressions are
  caught at author time, not in production; the rules are version-controlled,
  reviewable, and testable like any other code.
- **Trade-off:** policies must be maintained as the estate evolves (e.g. a new
  resource type needs a new rule). This is accepted as normal upkeep and is far
  cheaper than a production incident.
