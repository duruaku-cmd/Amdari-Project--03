# =====================================================================
# MODULE: identity  (Day 9)
# - Two SEPARATE ECS task roles (payments, kyc) -> fixes V-CLD-05.
# - GitHub OIDC provider + a scoped deploy role -> no long-lived keys
#   for the pipeline (prevents a repeat of V-CLD-04).
# Hard rule honoured throughout: no IAM policy grants "*" on "*".
# =====================================================================

locals {
  module_name = "identity"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ---------------------------------------------------------------------
# ECS task roles. Each service gets TWO roles, per AWS convention:
#   - execution role: lets ECS pull the image and write logs (startup).
#   - task role: the identity the RUNNING app uses to call AWS.
# On Day 9 the task roles start minimal (logs only). Days 10-12 attach
# narrowly-scoped permissions (this service's KMS key, its secret, etc).
# ---------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---- payments-api ----
resource "aws_iam_role" "payments_task" {
  name               = "${var.name_prefix}-payments-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Service = "payments-api" }
}

resource "aws_iam_role" "payments_exec" {
  name               = "${var.name_prefix}-payments-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Service = "payments-api" }
}

# ---- kyc-api ----
resource "aws_iam_role" "kyc_task" {
  name               = "${var.name_prefix}-kyc-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Service = "kyc-api" }
}

resource "aws_iam_role" "kyc_exec" {
  name               = "${var.name_prefix}-kyc-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Service = "kyc-api" }
}

# AWS-managed execution policy is the documented exception: it is scoped to
# ECR pull + CloudWatch Logs actions (not "*" on "*"), and is the AWS-blessed
# baseline for Fargate startup. Attached to EXECUTION roles only.
resource "aws_iam_role_policy_attachment" "payments_exec" {
  role       = aws_iam_role.payments_exec.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "kyc_exec" {
  role       = aws_iam_role.kyc_exec.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------
# GitHub Actions OIDC federation.
# The provider establishes trust in GitHub's token issuer. The role's trust
# policy then narrows WHO may assume it down to one repo and one branch.
# ---------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # GitHub's OIDC thumbprint. AWS now validates the cert chain directly, but
  # the field is still required by the API.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  github_oidc_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }
    # Audience must be the AWS STS audience.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Subject restricts to THIS repo and THIS ref. This is what stops any
    # other repository in the world from assuming your deploy role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:${var.github_ref}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${var.name_prefix}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_assume.json
  max_session_duration = 3600 # 1 hour; short-lived sessions only
  tags                 = { Purpose = "github-actions-oidc-deploy" }
}

# Day 9 keeps the deploy role's PERMISSIONS empty on purpose: the trust
# relationship is what we are establishing now. Week 3 attaches a scoped
# deployment policy. (Deliberately NOT AdministratorAccess -> avoids V-PIP-03.)
