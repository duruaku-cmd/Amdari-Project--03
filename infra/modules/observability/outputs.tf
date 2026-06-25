output "cloudtrail_bucket" {
  description = "Tamper-proof (Object Lock) bucket holding CloudTrail logs."
  value       = aws_s3_bucket.trail.id
}

output "cloudtrail_name" {
  value = aws_cloudtrail.main.name
}

output "honeytoken_user" {
  description = "Decoy IAM user. Any activity by this principal indicates compromise."
  value       = aws_iam_user.honeytoken.name
}

output "honeytoken_alarm" {
  value = aws_cloudwatch_metric_alarm.honeytoken_use.alarm_name
}

output "containment_lambda" {
  description = "Lambda that contains high-severity GuardDuty findings (tested in Week 3)."
  value       = aws_lambda_function.containment.function_name
}

output "guardduty_enabled" {
  value = var.enable_guardduty
}

output "security_hub_enabled" {
  value = var.enable_security_hub
}

output "config_enabled" {
  value = var.enable_config
}
