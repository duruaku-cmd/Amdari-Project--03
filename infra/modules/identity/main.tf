# =====================================================================
# MODULE: identity
# Purpose (built out later this week):
#   IAM: per-service ECS task roles (V-CLD-05), OIDC for GitHub Actions, IAM Identity Center notes, KMS key admin/use separation. Day 9.
#
# Day 8 status: scaffold only. No resources yet, so 'terraform plan'
# is clean and the module structure is committed up front.
# =====================================================================

locals {
  module_name = "identity"
}
