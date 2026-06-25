# =====================================================================
# Honeytoken — a DECOY IAM access key with ZERO permissions, placed where
# a compromised app could read it (an SSM parameter). It grants no access;
# its ONLY purpose is detection. Any use of it means the credential was
# stolen, so a CloudWatch alarm fires on the very first attempt.
# (Brief: honeytoken instrumented with an alarm that fires on use.)
# =====================================================================

# A user with NO policies attached -> the key it holds can do nothing.
resource "aws_iam_user" "honeytoken" {
  name = "${var.name_prefix}-decoy-svc"
  tags = {
    Name    = "${var.name_prefix}-honeytoken"
    Purpose = "honeytoken-do-not-use"
  }
}

# An explicit deny-everything policy: defence in depth, so even a future
# misconfiguration cannot grant this decoy any real power.
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

# Placed in SSM Parameter Store, a location a compromised app instance can
# reach -> exactly the "reachable from application memory" decoy the brief asks for.
resource "aws_ssm_parameter" "honeytoken_id" {
  name        = "/${var.name_prefix}/decoy/aws_access_key_id"
  description = "Decoy credential. Any use indicates compromise."
  type        = "SecureString"
  value       = aws_iam_access_key.honeytoken.id
  tags        = { Purpose = "honeytoken" }
}

resource "aws_ssm_parameter" "honeytoken_secret" {
  name        = "/${var.name_prefix}/decoy/aws_secret_access_key"
  description = "Decoy credential. Any use indicates compromise."
  type        = "SecureString"
  value       = aws_iam_access_key.honeytoken.secret
  tags        = { Purpose = "honeytoken" }
}

# --- Alarm on use ---
# Any API call by the decoy user appears in CloudTrail. We surface failed
# attempts (the decoy can ONLY fail, since it's deny-all) as a metric and
# alarm on the first one.
# Metric filter: count CloudTrail events where the user identity is the decoy.
# (Requires CloudTrail -> CloudWatch Logs delivery, configured below.)
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
  alarm_description   = "ALERT: the decoy credential was used. This indicates a credential theft / compromise."
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
