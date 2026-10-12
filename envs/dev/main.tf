module "platform" {
  source = "../../modules/platform"

  project     = "secure-aws-platform"
  environment = "dev"

  # Put your email here to get alarm notifications (or leave empty)
  alert_email = ""

  # Dev keeps logs for less time to save cost
  log_retention_days = 30
}
