variable "name_prefix" {
  description = "Common name prefix, e.g. sentinelpay-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 gives plenty of room for subnets."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span (brief requires >= 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "The architecture constraint requires at least two Availability Zones."
  }
}

variable "nat_strategy" {
  description = <<-EOT
    Controls the NAT Gateway, which is the main hourly cost on Day 9.
      "single" = one NAT Gateway shared by all private subnets (cheapest; ~$1/day).
      "per_az" = one NAT Gateway per AZ (full HA; ~$1/day each).
      "none"   = no NAT (free; private subnets have no outbound internet).
    Use "none" while validating, "single" for normal dev, "per_az" for production HA.
  EOT
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az", "none"], var.nat_strategy)
    error_message = "nat_strategy must be one of: single, per_az, none."
  }
}

variable "flow_log_retention_days" {
  description = "How long to keep VPC Flow Logs in CloudWatch."
  type        = number
  default     = 14
}
