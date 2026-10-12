# ---------------------------------------------------------------
# A small Python Lambda function with a least-privilege role
# ---------------------------------------------------------------

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/build/${local.name}-health.zip"
}

# Encrypted log group with retention, created before the function
resource "aws_cloudwatch_log_group" "lambda" {
  #checkov:skip=CKV_AWS_338:Retention is set per environment; dev uses 30 days to save cost, prod uses 365
  name              = "/aws/lambda/${local.name}-health"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.main.arn
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-health-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# Least privilege: only what this one function needs
data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  statement {
    sid       = "ListDataBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.data.arn]
  }

  statement {
    sid       = "ReadAppSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.app.arn]
  }

  statement {
    sid       = "UseEnvironmentKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.main.arn]
  }

  statement {
    sid       = "XRayTracing"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "least-privilege"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_lambda_function" "health" {
  #checkov:skip=CKV_AWS_117:Function does not need private network access; running outside a VPC avoids NAT gateway costs
  #checkov:skip=CKV_AWS_116:Invoked synchronously for health checks, so a dead-letter queue adds no value
  #checkov:skip=CKV_AWS_272:Code signing is out of scope for this learning project
  #checkov:skip=CKV_AWS_115:New accounts have a 10-execution limit that cannot be reserved; see comment below
  function_name = "${local.name}-health"
  description   = "Health check that verifies access to S3 and Secrets Manager"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  #Reserved concurrency is not set: new AWS accounts allow only 10 concurrent
  # executions in total, and AWS requires all 10 to stay unreserved.
  # Once the account limit is raised, add: reserved_concurrent_executions = 5
  kms_key_arn = aws_kms_key.main.arn

  environment {
    variables = {
      ENVIRONMENT = var.environment
      DATA_BUCKET = aws_s3_bucket.data.bucket
      SECRET_ARN  = aws_secretsmanager_secret.app.arn
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy.lambda]
}
