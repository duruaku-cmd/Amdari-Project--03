# =====================================================================
# Honeytoken — a DECOY IAM access key with ZERO permissions, placed where
# a compromised app could read it (an SSM parameter). It grants no access;
# its ONLY purpose is detection. Any use means the credential was stolen.
# =====================================================================

resource "aws_iam_user" "honeytoken" {
  name = "${var.name_prefix}-decoy-svc"
  tags = {
    Name    = "${var.name_prefix}-honeytoken"
    Purpose = "honeytoken-do-not-use"
  }
}

data "aws_iam_policy_document" "deny_all" {
  statement {
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "honeytoken_deny" {
  name   = "deny-all"
  user   = aws_iam_user.honeytoken.name
  policy = data.aws_iam_policy_document.deny_all.json
}

resource "aws_iam_access_key" "honeytoken" {
  user = aws_iam_user.honeytoken.name
}

# SecureString + customer-managed CMK (CKV_AWS_337).
resource "aws_ssm_parameter" "honeytoken_id" {
  name        = "/${var.name_prefix}/decoy/aws_access_key_id"
  description = "Decoy credential. Any use indicates compromise."
  type        = "SecureString"
  key_id      = var.kms_key_arn
  value       = aws_iam_access_key.honeytoken.id
  tags        = { Purpose = "honeytoken" }
}

resource "aws_ssm_parameter" "honeytoken_secret" {
  name        = "/${var.name_prefix}/decoy/aws_secret_access_key"
  description = "Decoy credential. Any use indicates compromise."
  type        = "SecureString"
  key_id      = var.kms_key_arn
  value       = aws_iam_access_key.honeytoken.secret
  tags        = { Purpose = "honeytoken" }
}

resource "aws_cloudwatch_log_metric_filter" "honeytoken_use" {
  name           = "${var.name_prefix}-honeytoken-use"
  log_group_name = aws_cloudwatch_log_group.trail.name
  pattern        = "{ $.userIdentity.userName = \"${aws_iam_user.honeytoken.name}\" }"

  metric_transformation {
    name          = "HoneytokenUse"
    namespace     = "SentinelPay/Security"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "honeytoken_use" {
  alarm_name          = "${var.name_prefix}-honeytoken-used"
  alarm_description   = "ALERT: the decoy credential was used. Indicates credential theft / compromise."
  namespace           = "SentinelPay/Security"
  metric_name         = "HoneytokenUse"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  tags                = { Purpose = "honeytoken-alarm" }
}
