# ---------------------------------------------------------------
# An application secret stored in Secrets Manager (never in code)
# ---------------------------------------------------------------

resource "random_password" "app" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "app" {
  #checkov:skip=CKV2_AWS_57:Automatic rotation needs a rotation Lambda; out of scope for this project
  name                    = "${local.name}/app-secret"
  description             = "Example application secret for ${local.name}"
  kms_key_id              = aws_kms_key.main.arn
  recovery_window_in_days = var.environment == "dev" ? 0 : 7
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    api_key = random_password.app.result
  })
}
