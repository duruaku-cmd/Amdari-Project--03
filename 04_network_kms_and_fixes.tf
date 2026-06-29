# ADD this new file: modules/network/kms.tf
# The network module is created BEFORE the data module, so it cannot use data's
# key (that would be a dependency cycle). It gets its own small CMK for flow logs.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

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
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
      }
    ]
  })
  tags = { Name = "${var.name_prefix}-network-cmk" }
}

resource "aws_kms_alias" "network" {
  name          = "alias/${var.name_prefix}-network"
  target_key_id = aws_kms_key.network.key_id
}

# network/main.tf does not declare aws_region; the kms.tf above references it.
# ADD this data source too (in kms.tf or main.tf):
#   data "aws_region" "current" {}
