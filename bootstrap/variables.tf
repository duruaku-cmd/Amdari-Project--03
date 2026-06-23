variable "aws_region" {
  description = "AWS region for the Terraform state backend resources."
  type        = string
  default     = "af-south-1" # SentinelPay primary region (Cape Town)
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name to hold Terraform state."
  type        = string
  # NOTE: S3 bucket names are global. Change the suffix to something unique to you.
  default     = "sentinelpay-tfstate-emmanuel"
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
  default     = "sentinelpay-tflock"
}

variable "tags" {
  description = "Mandatory tags applied to every resource (D-04 quality bar)."
  type        = map(string)
  default = {
    Owner       = "Emmanuel Duruaku"
    Environment = "shared"
    Service     = "terraform-state"
    CostCenter  = "security-platform"
  }
}
