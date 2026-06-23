# ADR 0001 — Remote Terraform State Backend (S3 + DynamoDB)

- **Status:** Accepted
- **Date:** 2026-06-23
- **Sprint/Day:** Week 2, Day 8 — Terraform Foundation
- **Author:** Emmanuel Duruaku

## Context

Terraform tracks the mapping between declared configuration and real AWS
resources in a *state file*. Stored locally, this file is a single point of
failure: it can be lost, it may contain sensitive values in plaintext, and it
permits only one operator at a time. For a team-graded, audit-oriented
engagement, state must be durable, encrypted, and safe under concurrent use.

A second problem is bootstrapping: the state backend is itself AWS
infrastructure, so it cannot store its own state in a backend that does not yet
exist.

## Decision

1. Use an **S3 bucket** for remote state storage and a **DynamoDB table** for
   state locking (`LockID` hash key). This is the canonical Terraform pattern.
2. Resolve the chicken-and-egg problem with a dedicated **`bootstrap/`**
   configuration that uses **local state** to create the bucket and table once.
   The bucket is versioned, KMS-encrypted, and has all public access blocked, and
   is protected with `prevent_destroy`.
3. All other configurations (`infra/` and everything built on Days 9–12) use the
   **S3 backend** with `encrypt = true` and the DynamoDB lock table.

## Consequences

- **Positive:** durable, encrypted, versioned state; safe concurrent applies;
  recoverable from a bad apply via S3 versioning; clean separation between the
  one-time bootstrap and day-to-day infrastructure.
- **Negative / trade-off:** the bootstrap’s own (local) state lives in the repo
  operator’s hands. This is acceptable because the bootstrap is tiny, changes
  rarely, and creates only two non-sensitive resources. It is committed and
  documented rather than hidden.
- **Operational note:** S3 bucket names are globally unique; the chosen name
  carries an operator-specific suffix. Region is `af-south-1` to match the
  SentinelPay primary region.
