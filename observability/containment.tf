# =====================================================================
# EventBridge -> Lambda containment (SOAR-style automated response).
# =====================================================================

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "containment" {
  name               = "${var.name_prefix}-containment-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = { Purpose = "guardduty-containment" }
}

data "aws_iam_policy_document" "containment" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:*:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {
    sid    = "ContainmentActions"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DescribeInstances",
      "iam:UpdateAccessKey",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "containment" {
  name   = "containment-actions"
  role   = aws_iam_role.containment.id
  policy = data.aws_iam_policy_document.containment.json
}

data "archive_file" "containment" {
  type        = "zip"
  output_path = "${path.module}/containment_lambda.zip"
  source {
    filename = "index.py"
    content  = <<-PY
      import json

      def handler(event, context):
          detail = event.get("detail", {})
          finding_type = detail.get("type", "unknown")
          severity = detail.get("severity", "unknown")
          print(f"[CONTAINMENT] High-severity GuardDuty finding received: "
                f"type={finding_type} severity={severity}")
          print(f"[CONTAINMENT] Full finding: {json.dumps(detail)[:1000]}")
          return {"status": "received", "type": finding_type, "severity": severity}
    PY
  }
}

# KMS-encrypted, 1-year retention (CKV_AWS_158, CKV_AWS_338).
resource "aws_cloudwatch_log_group" "containment" {
  name              = "/aws/lambda/${var.name_prefix}-containment"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

resource "aws_lambda_function" "containment" {
  function_name    = "${var.name_prefix}-containment"
  role             = aws_iam_role.containment.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = data.archive_file.containment.output_path
  source_code_hash = data.archive_file.containment.output_base64sha256
  timeout          = 30
  depends_on       = [aws_cloudwatch_log_group.containment]
  tags             = { Purpose = "guardduty-containment" }
}

resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${var.name_prefix}-guardduty-high-sev"
  description = "Route high-severity GuardDuty findings to the containment Lambda."
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.guardduty_finding_threshold] }]
    }
  })
  tags = { Purpose = "guardduty-containment" }
}

resource "aws_cloudwatch_event_target" "containment" {
  rule      = aws_cloudwatch_event_rule.guardduty_high.name
  target_id = "containment-lambda"
  arn       = aws_lambda_function.containment.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.containment.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_high.arn
}
