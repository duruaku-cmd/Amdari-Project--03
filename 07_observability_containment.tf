# In modules/observability/containment.tf:
# REPLACE the aws_cloudwatch_log_group.containment block with:
resource "aws_cloudwatch_log_group" "containment" {
  name              = "/aws/lambda/${var.name_prefix}-containment"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}
