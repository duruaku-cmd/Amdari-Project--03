# =====================================================================
# Network-local KMS key for VPC flow logs.
# The network module is created BEFORE the data module, so it cannot use
# the data module's CMK (that would be a dependency cycle). It owns a
# small CMK here, used only to encrypt the flow-log CloudWatch group.
# =====================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "network" {
  description             = "${var.name_prefix} network logs CMK (VPC flow logs)"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRoot"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = { Name = "${var.name_prefix}-network-cmk" }
}

resource "aws_kms_alias" "network" {
  name          = "alias/${var.name_prefix}-network"
  target_key_id = aws_kms_key.network.key_id
}
