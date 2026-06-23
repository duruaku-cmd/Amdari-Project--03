# =====================================================================
# RDS PostgreSQL — private subnets only, SG ingress BY REFERENCE.
# Fixes V-CLD-01 (public RDS). Encrypted with the customer-managed CMK.
# Credentials are generated and stored in Secrets Manager (see secrets.tf),
# never placed in code, env, or plaintext variables.
# =====================================================================

# DB subnet group pins RDS to the PRIVATE subnets across both AZs.
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.name_prefix}-db-subnets" }
}

# Security group for the database. NOTE: no ingress rule with a CIDR.
# Ingress is added by-reference from the app security groups only.
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Postgres access for SentinelPay app tier (by SG reference only)."
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound (RDS needs to reach AWS services)."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-db-sg" }
}

# Ingress BY REFERENCE: one rule per application security group.
# (Brief: "ingress restricted to the application security groups by reference,
# not by CIDR".) Empty on Day 10; populated when compute SG exists (Day 11).
resource "aws_security_group_rule" "db_ingress_from_app" {
  count                    = length(var.app_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = var.app_security_group_ids[count.index]
  description              = "Postgres from app SG (by reference)"
}

resource "aws_db_instance" "main" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  # --- Encryption at rest with the customer-managed CMK ---
  storage_encrypted = true
  kms_key_id        = aws_kms_key.data.arn

  db_name  = "sentinelpay"
  username = "sentinelpay_admin"
  # Password is MANAGED by Secrets Manager (no plaintext here, not in state as a
  # readable value). manage_master_user_password wires RDS <-> Secrets Manager.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.data.key_id

  # --- Network isolation: private only, not publicly accessible ---
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false # explicit: fixes V-CLD-01
  multi_az               = false # dev default; flip true for prod HA

  # --- Operational hardening ---
  backup_retention_period         = 1
  deletion_protection             = false # dev; set true in prod
  skip_final_snapshot             = true  # dev; set false in prod
  enabled_cloudwatch_logs_exports = ["postgresql"]
  auto_minor_version_upgrade      = true

  tags = { Name = "${var.name_prefix}-postgres", Service = "shared-data" }
}
