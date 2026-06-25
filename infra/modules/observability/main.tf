# =====================================================================
# MODULE: observability  (Day 12 - Detection Foundation)
# Files:
#   cloudtrail.tf          - tamper-proof audit trail (V-CLD-06)  [DEPLOYS]
#   honeytoken.tf          - decoy credential + alarm on use      [DEPLOYS]
#   containment.tf         - EventBridge -> Lambda containment     [DEPLOYS]
#   detection_services.tf  - GuardDuty/SecurityHub/Config (V-CLD-07)
#                            [account-gated; behind enable_* toggles]
# =====================================================================

terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

locals {
  module_name = "observability"
}
