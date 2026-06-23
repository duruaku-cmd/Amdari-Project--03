provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.tags
  }
}

# ---------------------------------------------------------------------------
# S3 bucket that stores the Terraform state file for all other configurations.
# Hardened from the start: versioned, encrypted, and all public access blocked.
# (These same controls are what V-CLD-02/03 require for data buckets later.)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # Safety: prevent accidental destruction of the bucket holding all state.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled" # keep history of state; allows recovery from a bad apply
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms" # customer-managed KMS comes in the data module; AWS-KMS here is fine for bootstrap
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# DynamoDB table providing the state LOCK. When someone runs `terraform apply`,
# Terraform writes a lock item here; a second concurrent run waits instead of
# corrupting state. PAY_PER_REQUEST keeps it inside free-tier-friendly costs.
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "tflock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID" # the exact attribute name Terraform expects

  attribute {
    name = "LockID"
    type = "S"
  }
}
