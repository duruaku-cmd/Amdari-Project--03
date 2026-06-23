output "state_bucket" {
  description = "Name of the S3 bucket holding Terraform state. Use in the backend block."
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table" {
  description = "Name of the DynamoDB lock table. Use in the backend block."
  value       = aws_dynamodb_table.tflock.name
}

output "region" {
  value = var.aws_region
}
