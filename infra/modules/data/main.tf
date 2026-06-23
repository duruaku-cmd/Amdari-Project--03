# =====================================================================
# MODULE: data  (Day 10)
# Resources are organised across focused files:
#   kms.tf          - customer-managed CMK with admin/user policy separation
#   rds.tf          - PostgreSQL, private subnets, SG-by-reference (V-CLD-01)
#   s3.tf           - KYC bucket: encryption/versioning/logging/PAB/Object Lock
#                     (V-CLD-02, V-CLD-03) + access-log bucket
#   elasticache.tf  - Redis, encrypted in transit+at rest, AUTH in Secrets Mgr
#   secrets.tf      - DB credential rotation via Secrets Manager
# This file intentionally holds only the module identifier.
# =====================================================================

locals {
  module_name = "data"
}

# random provider is used for the Redis AUTH token (elasticache.tf).
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
