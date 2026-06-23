# -----------------------------------------------------------------------------
# THIN ROOT CONFIGURATION
# Wires the five plane-modules together and passes shared inputs down.
# Real resources live in modules (D-04: modules independently testable,
# consumed by a thin root).
#
#   Day 9  -> network, identity   (ACTIVE)
#   Day 10 -> data
#   Day 11 -> compute (+ edge)
#   Day 12 -> observability
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "network" {
  source       = "./modules/network"
  name_prefix  = local.name_prefix
  nat_strategy = var.nat_strategy
}

module "identity" {
  source      = "./modules/identity"
  name_prefix = local.name_prefix
  github_org  = var.github_org
  github_repo = var.github_repo
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
