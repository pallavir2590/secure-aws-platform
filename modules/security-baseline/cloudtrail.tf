# ---------------------------------------------------------------
# CloudTrail: records who did what, when, and from where, for
# every API call in every region of the account.
# ---------------------------------------------------------------

resource "aws_cloudtrail" "main" {
  #checkov:skip=CKV2_AWS_10:Sending the trail to CloudWatch Logs costs extra; S3 archive is enough for this project
  #checkov:skip=CKV_AWS_252:SNS notification for each log file is not needed
  name           = local.trail_name
  s3_bucket_name = aws_s3_bucket.logs.id
  s3_key_prefix  = "cloudtrail"

  is_multi_region_trail         = true # covers every region, not just us-east-1
  include_global_service_events = true # includes IAM, STS, CloudFront events
  enable_log_file_validation    = true # detects if a log file is altered or deleted
  kms_key_id                    = aws_kms_key.logs.arn

  depends_on = [aws_s3_bucket_policy.logs]
}
