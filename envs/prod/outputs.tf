output "data_bucket_name" {
  value = module.platform.data_bucket_name
}

output "lambda_function_name" {
  value = module.platform.lambda_function_name
}

output "alerts_topic_arn" {
  value = module.platform.alerts_topic_arn
}

output "security_logs_bucket" {
  value = module.security_baseline.logs_bucket_name
}

output "cloudtrail_name" {
  value = module.security_baseline.cloudtrail_name
}

output "config_rules" {
  value = module.security_baseline.config_rule_names
}
