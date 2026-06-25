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

# --- Data plane (Day 10) ---
output "data_kms_key_arn" {
  value = module.data.kms_key_arn
}

output "db_endpoint" {
  value = module.data.db_endpoint
}

output "db_master_secret_arn" {
  value = module.data.db_master_secret_arn
}

output "kyc_bucket" {
  value = module.data.kyc_bucket
}

output "redis_endpoint" {
  value = module.data.redis_endpoint
}

# --- Compute & Edge (Day 11) ---
output "alb_dns_name" {
  description = "Public URL of the SentinelPay load balancer."
  value       = module.compute.alb_dns_name
}

output "app_security_group_id" {
  value = module.compute.app_security_group_id
}

output "waf_acl_arn" {
  value = module.compute.waf_acl_arn
}

output "ecs_cluster_name" {
  value = module.compute.ecs_cluster_name
}
