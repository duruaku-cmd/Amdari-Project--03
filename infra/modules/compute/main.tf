# =====================================================================
# MODULE: compute
# Purpose (built out later this week):
#   ECS Fargate services on private subnets, ALB, AWS WAF managed groups + custom rate-limit rule. Day 11.
#
# Day 8 status: scaffold only. No resources yet, so 'terraform plan'
# is clean and the module structure is committed up front.
# =====================================================================

locals {
  module_name = "compute"
}
