output "data_bucket_name" {
  value = module.platform.data_bucket_name
}

output "lambda_function_name" {
  value = module.platform.lambda_function_name
}

output "alerts_topic_arn" {
  value = module.platform.alerts_topic_arn
}
