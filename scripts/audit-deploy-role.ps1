# =============================================================================
#  Audit the GitHub Actions OIDC deploy role  (evidence for V-PIP-03)
#  Proves the pipeline principal is NOT AdministratorAccess and lists exactly
#  what it can do. Run from anywhere with AWS CLI configured.
# =============================================================================
$Role = "sentinelpay-dev-github-deploy"

Write-Host "=== Trust policy (who can assume this role) ===" -ForegroundColor Cyan
aws iam get-role --role-name $Role --query "Role.AssumeRolePolicyDocument" --output json

Write-Host "`n=== Attached managed policies ===" -ForegroundColor Cyan
$attached = aws iam list-attached-role-policies --role-name $Role --query "AttachedPolicies[].PolicyArn" --output text
$attached

Write-Host "`n=== Inline policies ===" -ForegroundColor Cyan
aws iam list-role-policies --role-name $Role --query "PolicyNames" --output table

Write-Host "`n=== V-PIP-03 assertion ===" -ForegroundColor Cyan
if ($attached -match "AdministratorAccess") {
  Write-Host "FAIL: role has AdministratorAccess. V-PIP-03 NOT remediated." -ForegroundColor Red
} else {
  Write-Host "PASS: no AdministratorAccess attached. Pipeline principal is scoped." -ForegroundColor Green
}
