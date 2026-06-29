# REPLACE the two aws_cloudwatch_log_group blocks in modules/compute/ecs.tf with these:

resource "aws_cloudwatch_log_group" "payments" {
  name              = "/ecs/${var.name_prefix}/payments"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "kyc" {
  name              = "/ecs/${var.name_prefix}/kyc"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}
