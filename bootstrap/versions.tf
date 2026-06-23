# Bootstrap uses LOCAL state on purpose: it creates the very S3 bucket and
# DynamoDB table that every other configuration will use as its remote backend.
# This resolves the chicken-and-egg problem (see docs/adr/0001-remote-state-backend.md).
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
