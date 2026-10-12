output "data_bucket_name" {
  value = aws_s3_bucket.data.bucket
}

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.health.function_name
}

output "secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
