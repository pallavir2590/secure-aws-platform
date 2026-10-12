# ---------------------------------------------------------------
# One customer-managed KMS key encrypts everything in this
# environment: S3 data, the secret, Lambda logs and SNS alerts.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "kms" {
  # In a KMS key policy, resources = ["*"] means "this key only", so these are false positives:
  #checkov:skip=CKV_AWS_111:Key policy resource "*" refers only to this key
  #checkov:skip=CKV_AWS_356:Key policy resource "*" refers only to this key
  #checkov:skip=CKV_AWS_109:Key policy resource "*" refers only to this key
  # The account (through IAM policies) can manage and use the key
  statement {
    sid       = "AllowAccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  # CloudWatch Logs can encrypt this environment's log groups
  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.name}-*"]
    }
  }

  # CloudWatch alarms can publish to the encrypted SNS topic
  statement {
    sid       = "AllowCloudWatchAlarmsToSNS"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "main" {
  description             = "${local.name} encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.main.key_id
}
