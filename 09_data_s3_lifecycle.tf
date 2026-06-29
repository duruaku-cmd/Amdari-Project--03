# ADD to modules/data/s3.tf (CKV2_AWS_61 lifecycle on both buckets):

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
