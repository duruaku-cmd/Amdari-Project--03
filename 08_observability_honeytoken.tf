# In modules/observability/honeytoken.tf:
# ADD `key_id = var.kms_key_arn` to BOTH aws_ssm_parameter resources.
# They are already SecureString, so only the key_id line is added:

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
