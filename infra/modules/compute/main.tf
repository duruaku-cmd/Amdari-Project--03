# =====================================================================
# MODULE: compute  (Day 11)
# Files:
#   security_groups.tf - the internet->ALB->app->db SG chain (by reference)
#   alb.tf             - Application Load Balancer + path routing
#   waf.tf             - WAF: Common/SQLi/KnownBadInputs + payments rate limit
#   ecs.tf             - Fargate cluster, task defs, services (private subnets)
# =====================================================================

locals {
  module_name = "compute"
}
