variable "aws_region" {
  description = "Primary AWS region for the SentinelPay deployment."
  type        = string
  default     = "af-south-1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project/service identifier used in resource names and tags."
  type        = string
  default     = "sentinelpay"
}

variable "owner" {
  description = "Owner tag applied to all resources."
  type        = string
  default     = "Emmanuel Duruaku"
}

variable "cost_center" {
  description = "CostCenter tag applied to all resources."
  type        = string
  default     = "security-platform"
}

variable "nat_strategy" {
  description = "NAT Gateway strategy: single (cheap), per_az (HA), or none (free, no outbound). See network module."
  type        = string
  default     = "single"
}

variable "github_org" {
  description = "GitHub username/org that owns the repo (OIDC trust)."
  type        = string
  default     = "duruaku-cmd"
}

variable "github_repo" {
  description = "Repository name for OIDC trust."
  type        = string
  default     = "Amdari-Project--03"
}

variable "enable_elasticache" {
  description = "Create the ElastiCache Redis cluster (data module). Off by default to save cost/time while validating."
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable GuardDuty (observability). Off by default: this account cannot subscribe."
  type        = bool
  default     = false
}

variable "enable_security_hub" {
  description = "Enable Security Hub FSBP+CIS. Off by default: account subscription required."
  type        = bool
  default     = false
}

variable "enable_config" {
  description = "Enable AWS Config + CIS pack. Off by default: account subscription required."
  type        = bool
  default     = false
}
