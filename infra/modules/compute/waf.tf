# =====================================================================
# AWS WAF (WAFv2) attached to the ALB. Brief requires:
#   - AWS Common rule set
#   - SQLi rule set
#   - XSS / Known Bad Inputs
#   - >= 1 custom rate-limit rule scoped to the payments endpoint
# =====================================================================

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name_prefix}-waf"
  description = "SentinelPay edge WAF: managed groups + payments rate limit."
  scope       = "REGIONAL" # REGIONAL = for ALB/API Gateway (CLOUDFRONT is the other option)

  default_action {
    allow {}
  }

  # ---- 1. AWS Common Rule Set ----
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

  # ---- 2. SQL injection rule set ----
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

  # ---- 3. Known Bad Inputs (includes XSS-style and exploit patterns) ----
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

  # ---- 4. CUSTOM rate-limit rule scoped to the payments endpoint ----
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
        # Scope the rate limit to the payments path only.
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

# Attach the WAF to the ALB.
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
