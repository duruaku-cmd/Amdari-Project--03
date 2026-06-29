# In modules/compute/waf.tf:

# (a) ADD a WAF logging configuration. WAF log group name MUST start "aws-waf-logs-".
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}

# (b) For CKV2_AWS_76 (Log4j AMR): ensure your web ACL includes the
#     AWSManagedRulesKnownBadInputsRuleSet managed rule group (it contains the
#     Log4j rule). If you already have AWSCommon/SQLi but NOT KnownBadInputs,
#     ADD this rule block inside aws_wafv2_web_acl.main (pick an unused priority):
#
#   rule {
#     name     = "AWSKnownBadInputs"
#     priority = 5
#     override_action { none {} }
#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesKnownBadInputsRuleSet"
#         vendor_name = "AWS"
#       }
#     }
#     visibility_config {
#       cloudwatch_metrics_enabled = true
#       metric_name                = "AWSKnownBadInputs"
#       sampled_requests_enabled   = true
#     }
#   }
