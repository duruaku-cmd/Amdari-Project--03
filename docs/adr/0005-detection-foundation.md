# ADR 0005 — Detection Foundation (and an Account Constraint)

- **Status:** Accepted
- **Date:** 2026-06-23
- **Sprint/Day:** Week 2, Day 12 — Detection Foundation
- **Author:** Emmanuel Duruaku

## Context

Days 8–11 built the preventive controls (segmentation, encryption, WAF, the
security-group chain). A defensible posture also requires *detective* controls
that reveal when those preventive layers are probed or breached. The red team
found detection essentially absent (challenge C-06, V-CLD-06, V-CLD-07):
GuardDuty off, CloudTrail writing to a bucket the account's own admins could
delete, no Security Hub, no responsible alerting.

## Decisions

1. **CloudTrail hardened for tamper-evidence (V-CLD-06).** A multi-region trail
   with log-file validation, KMS encryption (the data module CMK), and a
   destination S3 bucket with **Object Lock (Governance, 30 days)**, versioning,
   and a full public-access block. The trail also streams to CloudWatch Logs so
   metric-filter alarms can act on events. This is the direct fix for "logs to a
   bucket the administrators can delete": even a compromised admin cannot delete
   or alter the locked objects.

2. **Honeytoken tripwire.** A decoy IAM user with an explicit deny-all policy and
   an access key, placed in SSM Parameter Store — a location reachable from
   application memory, exactly as the brief specifies. The credential grants
   nothing; its only function is detection. A CloudWatch metric filter over the
   CloudTrail log stream matches any API call by the decoy principal and fires an
   alarm on the first use. Because the credential is otherwise useless, the
   alarm has near-zero false positives: use implies theft.

3. **EventBridge → Lambda containment, wired now.** An EventBridge rule matches
   high-severity (>= 7.0) GuardDuty findings and routes them to a containment
   Lambda with a scoped execution role (logs + specific EC2/IAM containment
   actions — no `*` on `*`). The wiring is deployed and ready; Week 3's attack
   simulation exercises the live containment path, as the brief requires.

## Account constraint (deliberate, documented trade-off)

This engagement runs in a **Free-Tier / sandbox AWS account that returns
`SubscriptionRequiredException` for GuardDuty, Security Hub, and AWS Config** —
these are not activatable on the account. Rather than leave the requirement
unaddressed or block all of Day 12:

- The Terraform for **GuardDuty (V-CLD-07)**, **Security Hub (FSBP + CIS)**, and
  **AWS Config (CIS pack)** is written to specification and committed, behind
  `enable_guardduty` / `enable_security_hub` / `enable_config` toggles that
  default to `false`. On any subscribing account, flipping a toggle deploys them
  unchanged — the design requirement is fully met in code and reviewable.
- The controls the account **does** permit — CloudTrail with Object Lock, the
  honeytoken and its alarm, and the EventBridge→Lambda containment — are
  **deployed for real**, producing genuine evidence.

This mirrors the Day 10 Free-Tier backup-retention adjustment: infrastructure
code must bend to account-level guardrails, and documenting the deviation with
justification is the audit-grade response. The distinction between *coded-and-
ready* and *deployed-and-evidenced* is stated explicitly so a reviewer can see
exactly what is live versus pending an account upgrade.

## Compliance with hard constraints

- No IAM policy grants `*` action on `*` resource. The containment role uses an
  explicit action list; the honeytoken policy is deny-all.
- All buckets are KMS-encrypted, versioned, and public-access-blocked.

## Consequences

- **Positive:** a tamper-proof audit trail and a working credential-theft
  tripwire are live now; the full managed-detection stack is one toggle away.
- **Trade-off:** until the account can subscribe, GuardDuty-sourced findings do
  not flow, so the containment Lambda receives no real events until Week 3 on a
  capable account. The honeytoken alarm is fully functional today and is the
  primary live detection control for the current account.
