# =====================================================================
# ElastiCache (Redis) — encryption in transit AND at rest, AUTH token in
# Secrets Manager (brief Data Plane constraint). Optional via toggle to
# save cost/time while validating.
# =====================================================================

# Generate a strong AUTH token and store it in Secrets Manager (not in code).
resource "random_password" "redis_auth" {
  count   = var.enable_elasticache ? 1 : 0
  length  = 32
  special = false # Redis AUTH disallows some specials; keep it alphanumeric
}

resource "aws_secretsmanager_secret" "redis_auth" {
  count      = var.enable_elasticache ? 1 : 0
  name       = "${var.name_prefix}/elasticache/auth-token"
  kms_key_id = aws_kms_key.data.arn
  tags       = { Service = "elasticache" }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  count         = var.enable_elasticache ? 1 : 0
  secret_id     = aws_secretsmanager_secret.redis_auth[0].id
  secret_string = random_password.redis_auth[0].result
}

resource "aws_elasticache_subnet_group" "main" {
  count      = var.enable_elasticache ? 1 : 0
  name       = "${var.name_prefix}-redis-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "redis" {
  count       = var.enable_elasticache ? 1 : 0
  name        = "${var.name_prefix}-redis-sg"
  description = "Redis access for app tier (by SG reference only)."
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.name_prefix}-redis-sg" }
}

resource "aws_security_group_rule" "redis_ingress_from_app" {
  count                    = var.enable_elasticache ? length(var.app_security_group_ids) : 0
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis[0].id
  source_security_group_id = var.app_security_group_ids[count.index]
  description              = "Redis from app SG (by reference)"
}

resource "aws_elasticache_replication_group" "main" {
  count                = var.enable_elasticache ? 1 : 0
  replication_group_id = "${var.name_prefix}-redis"
  description          = "SentinelPay session/cache store"
  engine               = "redis"
  node_type            = var.elasticache_node_type
  num_cache_clusters   = 1
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main[0].name
  security_group_ids   = [aws_security_group.redis[0].id]

  # Encryption: in transit (TLS) AND at rest (CMK), AUTH token from Secrets Manager.
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.data.arn
  auth_token                 = random_password.redis_auth[0].result

  tags = { Name = "${var.name_prefix}-redis", Service = "cache" }
}
