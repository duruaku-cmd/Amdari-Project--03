variable "name_prefix" {
  description = "Common name prefix, e.g. sentinelpay-dev."
  type        = string
}

variable "github_org" {
  description = "Your GitHub username or org that owns the repo (for OIDC trust)."
  type        = string
  default     = "duruaku-cmd"
}

variable "github_repo" {
  description = "The repository name OIDC will trust (without the org/owner part)."
  type        = string
  default     = "Amdari-Project--03"
}

variable "github_ref" {
  description = <<-EOT
    Which git ref may assume the deploy role. Scopes OIDC trust tightly.
    Default restricts to the main branch only.
  EOT
  type        = string
  default     = "refs/heads/main"
}

variable "create_github_oidc_provider" {
  description = <<-EOT
    Whether to create the GitHub OIDC provider. An AWS account can only have
    ONE provider for token.actions.githubusercontent.com. If you already have
    one (or hit an 'EntityAlreadyExists' error), set this to false.
  EOT
  type        = bool
  default     = true
}
