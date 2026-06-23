# =====================================================================
# MODULE: data
# Purpose (built out later this week):
#   RDS PostgreSQL (private, SG-by-reference, V-CLD-01), ElastiCache, S3 KYC bucket (KMS, versioning, access logging, public-access block, Object Lock = V-CLD-02/03), Secrets Manager + rotation. Day 10.
#
# Day 8 status: scaffold only. No resources yet, so 'terraform plan'
# is clean and the module structure is committed up front.
# =====================================================================

locals {
  module_name = "data"
}
