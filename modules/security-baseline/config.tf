# ---------------------------------------------------------------
# AWS Config: records the settings of key resources over time
# and continuously checks them against compliance rules.
# To keep cost low, it records only the resource types this
# project uses.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "config_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${local.name}-config"
  assume_role_policy = data.aws_iam_policy_document.config_trust.json
}

# AWS-managed policy that lets Config read resource settings
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

# A custom Config role delivers files to S3 using its own permissions,
# so it needs write access to the config/ prefix and the log key
data "aws_iam_policy_document" "config_delivery" {
  statement {
    sid       = "CheckBucket"
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [aws_s3_bucket.logs.arn]
  }

  statement {
    sid       = "WriteConfigFiles"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/config/AWSLogs/${local.account_id}/*"]
  }

  statement {
    sid       = "UseLogKey"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [aws_kms_key.logs.arn]
  }
}

resource "aws_iam_role_policy" "config_delivery" {
  name   = "config-delivery"
  role   = aws_iam_role.config.id
  policy = data.aws_iam_policy_document.config_delivery.json
}

resource "aws_config_configuration_recorder" "main" {
  #checkov:skip=CKV2_AWS_45:Records only this project's resource types to keep AWS Config costs low
  #checkov:skip=CKV2_AWS_48:Records only this project's resource types to keep AWS Config costs low
  name     = "${local.name}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = false
    resource_types = [
      "AWS::S3::Bucket",
      "AWS::IAM::Role",
      "AWS::IAM::Policy",
      "AWS::KMS::Key",
      "AWS::Lambda::Function",
      "AWS::SecretsManager::Secret",
      "AWS::CloudTrail::Trail",
      "AWS::SNS::Topic",
    ]
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${local.name}-delivery"
  s3_bucket_name = aws_s3_bucket.logs.id
  s3_key_prefix  = "config"
  s3_kms_key_arn = aws_kms_key.logs.arn

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main, aws_s3_bucket_policy.logs, aws_iam_role_policy.config_delivery]
}

# Turn the recorder on (must happen after the delivery channel exists)
resource "aws_config_configuration_recorder_status" "main" {
  #checkov:skip=CKV2_AWS_45:Records only this project's resource types to keep AWS Config costs low
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# AWS-managed compliance rules (no code to maintain)
locals {
  config_rules = {
    "s3-bucket-public-read-prohibited"         = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    "s3-bucket-server-side-encryption-enabled" = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    "s3-bucket-ssl-requests-only"              = "S3_BUCKET_SSL_REQUESTS_ONLY"
    "cmk-backing-key-rotation-enabled"         = "CMK_BACKING_KEY_ROTATION_ENABLED"
    "cloudtrail-enabled"                       = "CLOUD_TRAIL_ENABLED"
    "cloudtrail-log-file-validation-enabled"   = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED"
    "lambda-function-public-access-prohibited" = "LAMBDA_FUNCTION_PUBLIC_ACCESS_PROHIBITED"
    "iam-root-access-key-check"                = "IAM_ROOT_ACCESS_KEY_CHECK"
    "root-account-mfa-enabled"                 = "ROOT_ACCOUNT_MFA_ENABLED"
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = local.config_rules

  name = "${var.project}-${each.key}"

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [aws_config_configuration_recorder_status.main]
}
