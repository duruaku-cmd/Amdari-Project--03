# ADR 0003 — Data Plane: Customer-Managed Encryption & Secret Rotation

- **Status:** Accepted
- **Date:** 2026-06-23
- **Sprint/Day:** Week 2, Day 10 — Data Plane
- **Author:** Emmanuel Duruaku

## Context

The data plane holds SentinelPay's most sensitive assets: account balances,
the transaction ledger, and regulated KYC documents (BVN/NIN). The red team
found KYC documents in unencrypted S3 buckets with public-read ACLs (V-CLD-02,
V-CLD-03, challenge C-03), RDS reachable from the public internet (V-CLD-01,
C-05), and twelve long-lived credentials in source (V-CLD-04, C-04). Day 10
designs these anti-patterns out from the start.

## Decisions

1. **One customer-managed KMS CMK for data at rest**, with a key policy that
   separates *administer-policy* principals from *use-key* principals, and
   grants the data services (RDS, S3, ElastiCache, Secrets Manager, Logs) usage
   only. AWS-managed keys are explicitly rejected per the constraint. Automatic
   annual key rotation is enabled. A single well-scoped CMK per environment is
   chosen over per-service keys for operational simplicity; splitting later is
   non-breaking.

2. **RDS PostgreSQL is private and reference-gated.** It runs in the private
   subnets only via a DB subnet group, `publicly_accessible = false`
   (remediates V-CLD-01), and its security group takes **no CIDR ingress**.
   Ingress is granted by *security-group reference* from the application SGs,
   which do not exist until Day 11 — so the DB SG has zero ingress until compute
   is wired in, which is the safe default.

3. **RDS master credential is managed and rotated by Secrets Manager**
   (`manage_master_user_password`), encrypted with the CMK. No password appears
   in code, variables, or readable state. This satisfies the "secrets in
   Secrets Manager with rotation; not in env/code/state" constraint for the
   database credential.

4. **KYC bucket carries all five mandated controls:** default encryption with
   the CMK, versioning, server access logging to a dedicated log bucket,
   a full public-access block (making a public ACL impossible — remediates
   V-CLD-03), and Object Lock in **Governance** mode with a 30-day default
   retention. A bucket policy additionally denies non-TLS access. Governance
   (not Compliance) mode is chosen for dev so a privileged role can correct
   mistakes; Compliance mode is the production hardening step.

5. **ElastiCache is optional but compliant when enabled:** encryption in transit
   (TLS) and at rest (CMK), with the AUTH token generated at apply time and
   stored in Secrets Manager. Disabled by default to control cost during
   validation.

## Compliance with hard constraints

- No IAM/KMS statement grants `*` action on `*` resource. KMS key-policy
  statements use `resources = ["*"]` (which means "this key" — key policies are
  self-scoped) but always with an explicit, non-wildcard action list.
- Region note: the deployment is in `af-south-1`, which is outside the AWS Free
  Tier. RDS and ElastiCache therefore incur hourly cost; instance sizes are the
  smallest defensible (`db.t3.micro`, `cache.t3.micro`) and ElastiCache is
  opt-in.

## Consequences

- **Positive:** all data at rest is CMK-encrypted with enforced key-policy
  separation; the database is unreachable from the internet and gated by
  identity not address; KYC objects are tamper-resistant and access-logged; no
  database secret is ever human-visible.
- **Trade-off / deferred:** a dedicated non-admin application DB user with its
  own rotation Lambda is deferred; the rotation requirement is met for Day 10 by
  the RDS-managed master secret. ElastiCache off by default. Single-AZ RDS in
  dev (multi-AZ is a one-flag prod change).
