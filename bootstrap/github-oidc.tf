# ---------------------------------------------------------------
# GitHub Actions -> AWS login without stored access keys (OIDC)
# GitHub gives each workflow run a short-lived signed token.
# AWS trusts that token and hands back temporary credentials.
# ---------------------------------------------------------------

locals {
  repo_path = "${var.github_owner}/${var.github_repo}"
}

# Tell AWS to trust tokens issued by GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # GitHub's certificate thumbprints (AWS now validates GitHub tokens itself,
  # but the provider still accepts these values)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# ---------------- PLAN role (read-only) ----------------
# Used for terraform plan on pull requests and on main.
# It can read AWS and update the state lock, but cannot change infrastructure.

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.repo_path}:pull_request",
        "repo:${local.repo_path}:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "github-actions-terraform-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# The plan role also needs to write the state lock file in the state bucket
data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid       = "ReadWriteStateAndLock"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }
}

# terraform plan refreshes the Secrets Manager secret value, which the
# ReadOnlyAccess policy does not include. Allow reading only this project's
# secrets, and decrypting with KMS only when Secrets Manager asks for it.
data "aws_iam_policy_document" "plan_read_secrets" {
  statement {
    sid       = "ReadProjectSecrets"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.project}-*"]
  }

  statement {
    sid       = "DecryptViaSecretsManager"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["secretsmanager.*.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "plan_read_secrets" {
  name   = "read-project-secrets"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.plan_read_secrets.json
}

resource "aws_iam_role_policy" "plan_state_access" {
  name   = "terraform-state-access"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.state_access.json
}

# ---------------- APPLY role (makes changes) ----------------
# Only trusted from the protected GitHub "dev" and "prod" environments,
# so changes can only happen after merge to main (and approval for prod).

data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.repo_path}:environment:dev",
        "repo:${local.repo_path}:environment:prod"
      ]
    }
  }
}

resource "aws_iam_role" "github_apply" {
  name                 = "github-actions-terraform-apply"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_admin" {
  #checkov:skip=CKV_AWS_274:Deploy role must create IAM roles, KMS keys and more; risk limited by OIDC trust to protected environments only. Production would use a scoped custom policy.
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
