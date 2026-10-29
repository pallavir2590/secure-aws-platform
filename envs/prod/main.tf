# The same platform module as dev, with production settings
module "platform" {
  source = "../../modules/platform"

  project     = "secure-aws-platform"
  environment = "prod"

  # Put your email here to get alarm notifications (or leave empty)
  alert_email = ""

  # Prod keeps logs for a full year (the module default)
  log_retention_days = 365
}

# Account-wide security baseline: CloudTrail + AWS Config.
# It lives with prod because it protects the whole account and
# should only change through the approval-gated prod pipeline.
module "security_baseline" {
  source = "../../modules/security-baseline"

  project = "secure-aws-platform"
}
