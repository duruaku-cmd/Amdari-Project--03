# -----------------------------------------------------------------------------
# THIN ROOT CONFIGURATION
# This file does almost nothing itself. It only wires the five plane-modules
# together and passes shared inputs down. All real resources live in modules,
# which keeps the root readable and the modules independently testable (D-04).
#
# The modules are intentionally near-empty on Day 8. They are filled in over:
#   Day 9  -> network, identity
#   Day 10 -> data
#   Day 11 -> compute (+ edge)
#   Day 12 -> observability
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "network" {
  source      = "./modules/network"
  name_prefix = local.name_prefix
}

module "identity" {
  source      = "./modules/identity"
  name_prefix = local.name_prefix
}

module "data" {
  source      = "./modules/data"
  name_prefix = local.name_prefix
}

module "compute" {
  source      = "./modules/compute"
  name_prefix = local.name_prefix
}

module "observability" {
  source      = "./modules/observability"
  name_prefix = local.name_prefix
}
