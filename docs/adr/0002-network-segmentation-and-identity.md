# ADR 0002 — Network Segmentation & Service Identity

- **Status:** Accepted
- **Date:** 2026-06-23
- **Sprint/Day:** Week 2, Day 9 — Network & Identity
- **Author:** Emmanuel Duruaku

## Context

The red-team review found a flat VPC with a single security group allowing
`0.0.0.0/0` ingress on multiple ports, with RDS reachable from the public
internet (challenge C-05). It also found a single application IAM role carrying
`AdministratorAccess` (V-CLD-05) and twelve long-lived AWS keys in git history
(V-CLD-04). Day 9 establishes the network and identity foundations that make the
later data and compute planes safe to build.

## Decisions

1. **Segmented VPC.** A `/16` VPC split into public and private `/20` subnets
   across two Availability Zones. Application compute and data will live only in
   private subnets, satisfying "no application compute resource may be directly
   internet-addressable" and "private subnets across at least two AZs."

2. **NAT strategy is a variable, not a constant.** `nat_strategy` accepts
   `single` (one NAT, lowest cost), `per_az` (one per AZ, full HA), or `none`
   (no outbound, free). Default `single` for dev. This makes the main hourly
   cost an explicit, documented choice rather than a hidden default.

3. **VPC Flow Logs enabled** to a dedicated CloudWatch log group via a
   least-privilege role scoped to that log group only. Closes V-CLD-08.

4. **Separate ECS task roles per service.** `payments-api` and `kyc-api` each
   receive their own task role and execution role. A compromise of one service
   cannot assume the other's permissions. Directly remediates V-CLD-05. Task
   roles start with no standing permissions; scoped grants are attached on
   Days 10–12 as each service gains a dependency.

5. **GitHub Actions OIDC federation, established now.** An IAM OIDC provider for
   `token.actions.githubusercontent.com` plus a deploy role whose trust policy
   is scoped by `sub` to exactly `repo:<org>/<repo>:ref:refs/heads/main`. This
   is the mechanism that lets Week 3's pipeline obtain short-lived credentials
   with no long-lived keys, preventing a recurrence of V-CLD-04. The deploy
   role is created with **no** permissions on Day 9 (trust first; scoped deploy
   policy in Week 3) and is explicitly never `AdministratorAccess` (avoids
   V-PIP-03).

## Compliance with hard constraints

- No IAM policy grants `*` on `*`. The only AWS-managed policy used is
  `AmazonECSTaskExecutionRolePolicy`, attached to execution roles only; it is
  scoped to ECR pull and CloudWatch Logs, and is the AWS-recommended baseline.
- Session duration on the deploy role capped at one hour.

## Deferred / manual

- **IAM Identity Center with mandatory MFA and four-hour session cap** (human
  access) is an organisation-level configuration not reliably expressible in
  Terraform on a single personal account. It is recorded here as a manual
  console step to be evidenced with a screenshot, rather than code that may not
  apply cleanly. The constraint is acknowledged and satisfied operationally.

## Consequences

- **Positive:** internet-isolated compute tier; per-service blast-radius
  containment; keyless pipeline trust ready for Week 3; cost made explicit.
- **Trade-off:** a single NAT gateway (the dev default) is a single point of
  egress failure. Accepted for dev; `per_az` is one variable change for prod.
