terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # pinned (D-04: no provider may be unpinned)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Remote state backend created by ../bootstrap.
  # After running bootstrap, fill these in (or via -backend-config) and run `terraform init`.
  backend "s3" {
    bucket         = "sentinelpay-tfstate-emmanuel"
    key            = "sentinelpay/infra/terraform.tfstate"
    region         = "af-south-1"
    dynamodb_table = "sentinelpay-tflock"
    encrypt        = true
  }
}
