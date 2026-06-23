output "kms_key_arn" {
  description = "Customer-managed CMK protecting all data at rest."
  value       = aws_kms_key.data.arn
}

output "kms_key_alias" {
  value = aws_kms_alias.data.name
}

output "db_endpoint" {
  description = "RDS endpoint (host:port). Private; reachable only from app SGs."
  value       = aws_db_instance.main.address
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "db_security_group_id" {
  description = "DB security group; compute module references this for ingress-by-reference."
  value       = aws_security_group.db.id
}

output "db_master_secret_arn" {
  description = "Secrets Manager ARN of the rotated DB master credential."
  value       = local.db_master_secret_arn
}

output "kyc_bucket" {
  description = "KYC document bucket (encrypted, versioned, locked, private)."
  value       = aws_s3_bucket.kyc.id
}

output "kyc_logs_bucket" {
  value = aws_s3_bucket.kyc_logs.id
}

output "redis_endpoint" {
  description = "ElastiCache primary endpoint (null if disabled)."
  value       = var.enable_elasticache ? aws_elasticache_replication_group.main[0].primary_endpoint_address : null
}

output "redis_auth_secret_arn" {
  value = var.enable_elasticache ? aws_secretsmanager_secret.redis_auth[0].arn : null
}
