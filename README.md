# SentinelPay — Week 2 Cloud Infrastructure (Terraform)

Hardened AWS deployment for SentinelPay, provisioned entirely from Terraform.
This is **Deliverable D-04**. Built out over Week 2:

| Day | Plane | Module |
| --- | --- | --- |
| 8  | Foundation | state backend (`bootstrap/`) + module scaffold |
| 9  | Network & Identity | `modules/network`, `modules/identity` |
| 10 | Data | `modules/data` |
| 11 | Compute & Edge | `modules/compute` |
| 12 | Detection | `modules/observability` |
| 13 | Policy as Code | OPA/Rego (separate pack, D-05) |
| 14 | Review | Well-Architected self-assessment + diagram |

## Layout

```
bootstrap/        # one-time: creates the S3 state bucket + DynamoDB lock table (local state)
infra/            # the thin root configuration (remote S3 backend)
  modules/
    network/      identity/   data/   compute/   observability/
docs/adr/         # Architecture Decision Records
```

## First-time setup

```powershell
# 1. Create the remote state backend (run ONCE)
cd bootstrap
terraform init
terraform apply        # creates the S3 bucket + DynamoDB table

# 2. Initialise the infra root against that backend
cd ..\infra
terraform init         # migrates to the S3 backend
make plan              # or: terraform plan
```

## Conventions
- Terraform >= 1.7, AWS provider pinned `~> 5.0`.
- Every resource is tagged Owner / Environment / Service / Project / CostCenter via provider `default_tags`.
- One ADR per significant decision in `docs/adr/`.
- State, plans, and `.terraform/` are git-ignored.
