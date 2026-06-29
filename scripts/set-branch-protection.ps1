# =============================================================================
#  Apply branch protection to main  (remediates V-PIP-04)
#  Requires: GitHub CLI (gh) authenticated  ->  gh auth login
#  Run from anywhere. Edit $Owner/$Repo if they ever change.
# =============================================================================
$Owner = "duruaku-cmd"
$Repo  = "Amdari-Project--03"
$Branch = "main"

Write-Host "Applying branch protection to $Owner/$Repo@$Branch ..." -ForegroundColor Cyan

# The required status checks must match the JOB NAMES in pipeline.yml.
$body = @{
  required_status_checks = @{
    strict   = $true                       # branch must be up to date before merge
    contexts = @(
      "Secret Scanning",
      "SAST",
      "Dependency Scan (SCA)",
      "IaC Scan + OPA",
      "Verify Deploy Identity (OIDC)",
      "Pipeline Status (fail closed)"
    )
  }
  enforce_admins = $true                   # even admins cannot bypass
  required_pull_request_reviews = @{
    required_approving_review_count = 1     # at least one reviewer (separation of duties)
    dismiss_stale_reviews           = $true
    require_code_owner_reviews      = $false
  }
  restrictions      = $null
  allow_force_pushes = $false
  allow_deletions    = $false
  required_linear_history = $true
} | ConvertTo-Json -Depth 6

$body | gh api -X PUT "repos/$Owner/$Repo/branches/$Branch/protection" --input -

Write-Host "Done. Verify in GitHub -> Settings -> Branches." -ForegroundColor Green
