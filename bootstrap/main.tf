# Looks up the AWS account we are logged in to,
# so the bucket name is unique to this account.
data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# S3 bucket that stores Terraform state for the dev and prod environments
resource "aws_s3_bucket" "tfstate" {
  # Accepted risks for a low-traffic, single-user learning state bucket:
  #checkov:skip=CKV_AWS_144:Cross-region replication not needed for a learning project
  #checkov:skip=CKV_AWS_18:Access logging would need a second bucket; versioning covers recovery
  #checkov:skip=CKV2_AWS_62:Event notifications not needed for a state bucket
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) is enough here and avoids KMS key costs
  bucket = local.state_bucket_name

  # Protects the bucket from being deleted by accident with terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}

# Keep every version of the state file, so a bad change can be rolled back
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (state files can contain sensitive values)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block every form of public access
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Only allow encrypted (HTTPS) connections to the bucket
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# Clean up old state versions after 90 days to keep costs near zero
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}