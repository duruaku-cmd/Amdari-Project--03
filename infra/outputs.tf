output "name_prefix" {
  description = "The common name prefix for this environment."
  value       = local.name_prefix
}

# --- Network (Day 9) ---
output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "availability_zones" {
  value = module.network.availability_zones
}

output "vpc_flow_log_group" {
  value = module.network.flow_log_group
}

# --- Identity (Day 9) ---
output "payments_task_role_arn" {
  value = module.identity.payments_task_role_arn
}

output "kyc_task_role_arn" {
  value = module.identity.kyc_task_role_arn
}

output "github_deploy_role_arn" {
  value = module.identity.github_deploy_role_arn
}
