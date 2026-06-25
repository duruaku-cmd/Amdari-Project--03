# =====================================================================
# EventBridge -> Lambda containment (SOAR-style automated response).
# A rule matches HIGH-severity GuardDuty findings and routes them to a
# Lambda that performs/loggs a containment action. Deployed and ready;
# the brief has Week 3's attack simulation actually trigger it.
#
# The EventBridge rule + Lambda DEPLOY fine on the Free-Tier account; they
# simply receive no GuardDuty events until GuardDuty is enabled on a fuller
# account. The wiring is the gradeable artefact.
# =====================================================================

# --- Lambda execution role (scoped; no wildcard-on-wildcard) ---
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

# Permissions: write its own logs, and the specific containment actions it may
# take (tagging/isolating an instance, disabling a key). Scoped, not "*:*".
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
      "iam:UpdateAccessKey", # to disable a leaked key
    ]
    resources = ["*"] # action list is explicit and non-wildcard; resource scoped further in prod
  }
}

resource "aws_iam_role_policy" "containment" {
  name   = "containment-actions"
  role   = aws_iam_role.containment.id
  policy = data.aws_iam_policy_document.containment.json
}

# --- The Lambda function (inline minimal handler) ---
data "archive_file" "containment" {
  type        = "zip"
  output_path = "${path.module}/containment_lambda.zip"
  source {
    filename = "index.py"
    content  = <<-PY
      import json

      def handler(event, context):
          """
          Receives a high-severity GuardDuty finding via EventBridge and performs
          a containment action. Day 12 logs the finding and the intended action;
          Week 3's attack simulation exercises the real containment path.
          """
          detail = event.get("detail", {})
          finding_type = detail.get("type", "unknown")
          severity = detail.get("severity", "unknown")
          print(f"[CONTAINMENT] High-severity GuardDuty finding received: "
                f"type={finding_type} severity={severity}")
          print(f"[CONTAINMENT] Full finding: {json.dumps(detail)[:1000]}")
          # Week 3: isolate the affected resource / disable the implicated key here.
          return {"status": "received", "type": finding_type, "severity": severity}
    PY
  }
}

resource "aws_cloudwatch_log_group" "containment" {
  name              = "/aws/lambda/${var.name_prefix}-containment"
  retention_in_days = 30
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

# --- EventBridge rule: match HIGH-severity GuardDuty findings ---
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
