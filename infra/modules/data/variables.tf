variable "name_prefix" {
  description = "Common name prefix, e.g. sentinelpay-dev."
  type        = string
}

# --- wiring from other modules (passed by the root) ---
variable "vpc_id" {
  description = "VPC ID from the network module."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (RDS and ElastiCache live here only)."
  type        = list(string)
}

variable "app_security_group_ids" {
  description = <<-EOT
    Security group IDs of the application compute (payments/kyc). DB ingress is
    granted to these by REFERENCE, not by CIDR (brief Data Plane constraint).
    Empty on Day 10 (compute doesn't exist yet); the compute module on Day 11
    will create its SG and we'll wire it in then. Until then the DB SG has no
    ingress, which is the safe default.
  EOT
  type        = list(string)
  default     = []
}

# --- sizing / cost toggles ---
variable "db_instance_class" {
  description = "RDS instance size. db.t3.micro is the smallest; note af-south-1 is not free-tier."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GB."
  type        = number
  default     = 20
}

variable "enable_elasticache" {
  description = "Whether to create the ElastiCache (Redis) cluster. Set false while validating to save cost/time."
  type        = bool
  default     = false
}

variable "elasticache_node_type" {
  description = "ElastiCache node size."
  type        = string
  default     = "cache.t3.micro"
}

variable "enable_db_rotation" {
  description = "Whether to attach the Secrets Manager rotation schedule (managed rotation Lambda)."
  type        = bool
  default     = true
}

variable "kms_admin_arns" {
  description = <<-EOT
    IAM principal ARNs allowed to ADMINISTER the KMS keys (change policy), as
    distinct from those allowed to USE them. Separation is a brief requirement.
    Defaults to empty; if empty, the module uses the account root as admin,
    which is the documented baseline for a single-operator dev account.
  EOT
  type        = list(string)
  default     = []
}
