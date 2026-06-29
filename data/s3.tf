# =====================================================================
# S3 KYC document bucket - the five mandated controls + lifecycle.
# Fixes V-CLD-02 (unencrypted) and V-CLD-03 (public ACL).
# =====================================================================

resource "aws_s3_bucket" "kyc_logs" {
  bucket = "${var.name_prefix}-kyc-access-logs-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.name_prefix}-kyc-access-logs", Purpose = "s3-access-logs" }
}

resource "aws_s3_bucket_public_access_block" "kyc_logs" {
  bucket                  = aws_s3_bucket.kyc_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "kyc_logs" {
  bucket = aws_s3_bucket.kyc_logs.id
  versioning_configuration { status = "Enabled" }
}

# Log-target bucket uses SSE-S3 (AES256) BY DESIGN: SSE-KMS on an S3
# server-access-log target blocks log delivery. (CKV_AWS_145 skip is justified.)
resource "aws_s3_bucket_server_side_encryption_configuration" "kyc_logs" {
  bucket = aws_s3_bucket.kyc_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# Lifecycle (CKV2_AWS_61).
resource "aws_s3_bucket_lifecycle_configuration" "kyc_logs" {
  bucket = aws_s3_bucket.kyc_logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# --- The KYC document bucket itself ---
resource "aws_s3_bucket" "kyc" {
  bucket              = "${var.name_prefix}-kyc-documents-${data.aws_caller_identity.current.account_id}"
  object_lock_enabled = true
  tags                = { Name = "${var.name_prefix}-kyc-documents", Service = "kyc-api", DataClass = "regulated-pii" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kyc" {
  bucket = aws_s3_bucket.kyc.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "kyc" {
  bucket = aws_s3_bucket.kyc.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_logging" "kyc" {
  bucket        = aws_s3_bucket.kyc.id
  target_bucket = aws_s3_bucket.kyc_logs.id
  target_prefix = "kyc-access/"
}

resource "aws_s3_bucket_public_access_block" "kyc" {
  bucket                  = aws_s3_bucket.kyc.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "kyc" {
  bucket = aws_s3_bucket.kyc.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
  }
}

# Lifecycle (CKV2_AWS_61) - noncurrent-only, compatible with Object Lock.
resource "aws_s3_bucket_lifecycle_configuration" "kyc" {
  bucket = aws_s3_bucket.kyc.id
  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

data "aws_iam_policy_document" "kyc_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.kyc.arn, "${aws_s3_bucket.kyc.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "kyc" {
  bucket = aws_s3_bucket.kyc.id
  policy = data.aws_iam_policy_document.kyc_tls_only.json
}
