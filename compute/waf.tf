# =====================================================================
# AWS WAF (WAFv2) attached to the ALB. Brief requires:
#   - AWS Common rule set
#   - SQLi rule set
#   - XSS / Known Bad Inputs (includes the Log4j RCE rule)
#   - >= 1 custom rate-limit rule scoped to the payments endpoint
#   - logging configuration (CKV2_AWS_31)
# =====================================================================

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name_prefix}-waf"
  description = "SentinelPay edge WAF: managed groups + payments rate limit."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSCommon"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSSQLi"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Known Bad Inputs INCLUDES the Log4j RCE rule -> satisfies CKV2_AWS_76.
  rule {
    name     = "AWSKnownBadInputs"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-badinputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "PaymentsRateLimit"
    priority = 10
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.payments_rate_limit
        aggregate_key_type = "IP"
        scope_down_statement {
          byte_match_statement {
            positional_constraint = "STARTS_WITH"
            search_string         = "/payments"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-payments-ratelimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = { Name = "${var.name_prefix}-waf" }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ---- WAF logging configuration (CKV2_AWS_31) ----
# WAF log group name MUST start with "aws-waf-logs-".
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}
