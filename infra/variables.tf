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
