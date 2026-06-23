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

  # network wiring (Day 9 outputs)
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # app SGs are created in the compute module on Day 11; wired in then.
  app_security_group_ids = []

  # cost/scope toggles
  enable_elasticache = var.enable_elasticache
  enable_db_rotation = true
}

module "compute" {
  source      = "./modules/compute"
  name_prefix = local.name_prefix
}

module "observability" {
  source      = "./modules/observability"
  name_prefix = local.name_prefix
}
