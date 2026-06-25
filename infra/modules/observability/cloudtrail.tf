# =====================================================================
# CloudTrail — the tamper-proof audit record (closes V-CLD-06).
# Log-file validation + KMS encryption + Object Lock on the destination
# bucket, so an attacker who compromises an admin still cannot delete or
# alter the evidence. This part DEPLOYS on the Free-Tier account.
# =====================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# --- Destination bucket with Object Lock enabled at creation ---
resource "aws_s3_bucket" "trail" {
  bucket              = "${var.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  object_lock_enabled = true
  tags                = { Name = "${var.name_prefix}-cloudtrail", Purpose = "audit-log" }
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy allowing CloudTrail to write, and denying non-TLS access.
data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
  statement {
    sid       = "AWSCloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
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

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket.json
}

# --- The trail itself: validation + KMS, multi-region ---
resource "aws_cloudtrail" "main" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  enable_log_file_validation    = true # tamper-evidence
  include_global_service_events = true
  is_multi_region_trail         = true
  kms_key_id                    = var.kms_key_arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.trail_to_cwl.arn

  depends_on = [aws_s3_bucket_policy.trail, aws_iam_role_policy.trail_to_cwl]
  tags       = { Name = "${var.name_prefix}-trail" }
}

# --- CloudTrail -> CloudWatch Logs delivery ---
# The honeytoken metric filter watches a CloudWatch log group, so the trail
# must also stream to CloudWatch (in addition to the Object Lock S3 bucket).
resource "aws_cloudwatch_log_group" "trail" {
  name              = "/sentinelpay/${var.name_prefix}/cloudtrail"
  retention_in_days = 90
}

data "aws_iam_policy_document" "trail_to_cwl_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "trail_to_cwl" {
  name               = "${var.name_prefix}-trail-to-cwl"
  assume_role_policy = data.aws_iam_policy_document.trail_to_cwl_assume.json
}

data "aws_iam_policy_document" "trail_to_cwl" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "trail_to_cwl" {
  name   = "deliver-to-cwl"
  role   = aws_iam_role.trail_to_cwl.id
  policy = data.aws_iam_policy_document.trail_to_cwl.json
}
