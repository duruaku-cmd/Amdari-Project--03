# ADR 0004 — Compute & Edge: Fargate, ALB, and WAF

- **Status:** Accepted
- **Date:** 2026-06-23
- **Sprint/Day:** Week 2, Day 11 — Compute & Edge
- **Author:** Emmanuel Duruaku

## Context

The patched SentinelPay applications need a runtime that keeps them off the
public internet while still serving traffic, with attack filtering at the edge.
This day also closes the data-plane loop left open on Day 10, where the RDS
security group had no ingress because the application security group did not yet
exist.

## Decisions

1. **ECS Fargate** for compute. Serverless containers remove host management and
   fit the existing Docker-image packaging from Week 1. EKS was available but
   rejected as heavier than this workload needs; the choice is defensible under
   the "free to choose orchestrator" latitude.

2. **Single internet entry point via an internet-facing ALB** in the public
   subnets. All tasks run in **private** subnets with `assign_public_ip = false`,
   satisfying "no application compute resource may be directly
   internet-addressable." The ALB is Layer 7, which is required for WAF
   attachment and lets us path-route `/payments/*` and `/kyc/*` to the two
   services.

3. **Security-group chain enforced by reference, not CIDR.** internet → ALB SG
   (the only public-facing SG) → app SG (ingress only from ALB SG) → RDS SG
   (ingress only from app SG, wired this day). Each hop is identity-based. This
   completes the Data Plane constraint "ingress restricted to the application
   security groups by reference (not by CIDR)."

4. **AWS WAF on the ALB** with the AWS Common, SQLi, and Known Bad Inputs
   (XSS-class) managed rule groups, plus a **custom rate-based rule scoped to the
   `/payments` path**. This is the cloud-layer complement to the Week 1
   application rate limiter (V-APP-08) and the parameterised-query fix
   (V-APP-01).

5. **Separate task roles retained.** payments-api runs under the payments task
   role and kyc-api under the kyc task role (from Day 9), preserving the V-CLD-05
   remediation: a compromise of one service cannot assume the other's identity.

## Deliberate scope choices (documented, not omissions)

- **Container images are a variable defaulting to a public placeholder
  (`nginx`).** Real application images belong in ECR and are pushed by the
  Week 3 pipeline (Day 15). The Day 11 deliverable is the *architecture* —
  Fargate, ALB, WAF, the SG chain — which is fully real and testable now. The
  image swap is a one-line variable change once images exist.

- **HTTP (:80) listener only; no ACM certificate or custom domain.** The brief's
  Route 53 + DNSSEC constraint applies to "any hosted zones the deployment
  introduces." This deployment introduces none — the ALB DNS name is sufficient
  for the engagement — so the constraint is satisfied by not introducing a zone.
  Production hardening (443 listener, ACM cert, 80→443 redirect, Route 53 with
  DNSSEC) is noted as the next step.

- **No SSH/exec into tasks.** ECS Exec is left disabled; the "break-glass only"
  access constraint is met by having no interactive access path at all in dev.

## Compliance with hard constraints

- No IAM policy grants `*` on `*`. Task roles are the scoped roles from Day 9.
- All resources tagged via provider `default_tags`.

## Consequences

- **Positive:** compute is internet-isolated; a single, WAF-protected entry
  point; identity-based network segmentation end to end; the data plane is now
  reachable only through the intended path.
- **Cost:** adds an ALB (~$0.50/day) and Fargate tasks. Task count and size are
  minimal (1 task each, 0.25 vCPU). Scale `desired_count` to 0 to pause.
- **Trade-off:** placeholder images mean the ALB health checks pass against
  nginx, not the real apps, until Week 3 wires in ECR images.
