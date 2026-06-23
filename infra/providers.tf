# Single place that configures the AWS provider and the MANDATORY default tags.
# default_tags means every taggable resource in every module automatically gets
# Owner / Environment / Service / Project / CostCenter without repeating them.
# (D-04 quality bar: "Every resource carries Owner, Environment, Service, CostCenter tags.")
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Owner       = var.owner
      Environment = var.environment
      Project     = var.project
      Service     = var.project
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
    }
  }
}
