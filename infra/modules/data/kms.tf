# =====================================================================
# Customer-managed KMS keys (brief: AWS-managed keys are NOT acceptable).
# Key POLICY separates administer-policy principals from use-key principals.
# One key for data-at-rest (RDS, S3, ElastiCache); could be split further,
# but a single well-scoped CMK per environment is a defensible choice (ADR).
# =====================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_root = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  # If no explicit admins given, the account root administers the key (dev baseline).
  kms_admins = length(var.kms_admin_arns) > 0 ? var.kms_admin_arns : [local.account_root]
}

data "aws_iam_policy_document" "data_kms" {
  # --- ADMIN statement: manage the key policy, but this set is for administration ---
  statement {
    sid       = "KeyAdministration"
    effect    = "Allow"
    actions   = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
      "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
      "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
      "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
    ]
    resources = ["*"] # "*" here means "this key" (key policies are self-scoped); action is NOT *
    principals {
      type        = "AWS"
      identifiers = local.kms_admins
    }
  }

  # --- USE statement: encrypt/decrypt for the data services, no policy control ---
  statement {
    sid       = "KeyUsageByServices"
    effect    = "Allow"
    actions   = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.account_root] # scoped further by grants; service principals below
    }
  }

  # --- Allow AWS services (RDS, S3, ElastiCache, Secrets, Logs) to use the key ---
  statement {
    sid       = "AllowServiceUse"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = [
        "rds.amazonaws.com",
        "s3.amazonaws.com",
        "elasticache.amazonaws.com",
        "secretsmanager.amazonaws.com",
        "logs.${data.aws_region.current.name}.amazonaws.com",
        "cloudtrail.amazonaws.com",
      ]
    }
  }
}

resource "aws_kms_key" "data" {
  description             = "${var.name_prefix} customer-managed key for data at rest (RDS/S3/ElastiCache/Secrets)."
  deletion_window_in_days = 7
  enable_key_rotation     = true # annual automatic rotation of the CMK
  policy                  = data.aws_iam_policy_document.data_kms.json
  tags                    = { Name = "${var.name_prefix}-data-kms" }
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name_prefix}-data"
  target_key_id = aws_kms_key.data.key_id
}
