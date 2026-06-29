# In modules/observability/cloudtrail.tf:

# (a) REPLACE the aws_cloudwatch_log_group.trail block with:
resource "aws_cloudwatch_log_group" "trail" {
  name              = "/sentinelpay/${var.name_prefix}/cloudtrail"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

# (b) ADD a lifecycle configuration for the trail bucket (CKV2_AWS_61):
resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}
