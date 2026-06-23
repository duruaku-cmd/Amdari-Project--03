# =====================================================================
# MODULE: observability
# Purpose (built out later this week):
#   GuardDuty (V-CLD-07), CloudTrail w/ Object Lock + validation (V-CLD-06), Security Hub, AWS Config, honeytoken, EventBridge to Lambda containment. Day 12.
#
# Day 8 status: scaffold only. No resources yet, so 'terraform plan'
# is clean and the module structure is committed up front.
# =====================================================================

locals {
  module_name = "observability"
}
