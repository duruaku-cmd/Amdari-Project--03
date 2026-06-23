# =====================================================================
# S3 KYC document bucket — the five mandated controls:
#   default encryption (CMK), versioning, server access logging,
#   public access block, Object Lock (Governance Mode).
# Fixes V-CLD-02 (unencrypted) and V-CLD-03 (public ACL).
# =====================================================================

# --- Separate bucket to receive SERVER ACCESS LOGS for the KYC bucket ---
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

# Log buckets must allow the logging service to write; SSE-KMS on a log target
# can block delivery, so the access-log bucket uses SSE-S3 (AES256). The KYC
# bucket itself uses the CMK (below).
resource "aws_s3_bucket_server_side_encryption_configuration" "kyc_logs" {
  bucket = aws_s3_bucket.kyc_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# --- The KYC document bucket itself ---
# Object Lock MUST be enabled at creation time (object_lock_enabled = true).
resource "aws_s3_bucket" "kyc" {
  bucket              = "${var.name_prefix}-kyc-documents-${data.aws_caller_identity.current.account_id}"
  object_lock_enabled = true
  tags                = { Name = "${var.name_prefix}-kyc-documents", Service = "kyc-api", DataClass = "regulated-pii" }
}

# 1) Default encryption with the customer-managed CMK -> fixes V-CLD-02
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

# 2) Versioning (required, and a prerequisite for Object Lock)
resource "aws_s3_bucket_versioning" "kyc" {
  bucket = aws_s3_bucket.kyc.id
  versioning_configuration { status = "Enabled" }
}

# 3) Server access logging -> the separate log bucket
resource "aws_s3_bucket_logging" "kyc" {
  bucket        = aws_s3_bucket.kyc.id
  target_bucket = aws_s3_bucket.kyc_logs.id
  target_prefix = "kyc-access/"
}

# 4) Public access block -> makes a public ACL impossible -> fixes V-CLD-03
resource "aws_s3_bucket_public_access_block" "kyc" {
  bucket                  = aws_s3_bucket.kyc.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5) Object Lock in GOVERNANCE mode with a default retention
resource "aws_s3_bucket_object_lock_configuration" "kyc" {
  bucket = aws_s3_bucket.kyc.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
  }
}

# Belt-and-braces: a bucket policy that denies any non-TLS access.
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
