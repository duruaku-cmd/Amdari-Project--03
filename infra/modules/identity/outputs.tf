output "payments_task_role_arn" {
  description = "ARN of the payments-api task role (the running app's identity)."
  value       = aws_iam_role.payments_task.arn
}

output "payments_exec_role_arn" {
  value = aws_iam_role.payments_exec.arn
}

output "kyc_task_role_arn" {
  description = "ARN of the kyc-api task role (separate identity -> fixes V-CLD-05)."
  value       = aws_iam_role.kyc_task.arn
}

output "kyc_exec_role_arn" {
  value = aws_iam_role.kyc_exec.arn
}

output "github_deploy_role_arn" {
  description = "ARN the GitHub Actions workflow will assume via OIDC in Week 3."
  value       = aws_iam_role.github_deploy.arn
}

output "github_oidc_provider_arn" {
  value = local.github_oidc_arn
}
