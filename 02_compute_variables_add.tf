# ADD to modules/compute/variables.tf:

variable "kms_key_arn" {
  type        = string
  description = "Customer-managed KMS key ARN for encrypting CloudWatch log groups."
}
