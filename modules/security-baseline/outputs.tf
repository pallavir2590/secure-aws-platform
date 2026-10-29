output "logs_bucket_name" {
  value = aws_s3_bucket.logs.bucket
}

output "cloudtrail_name" {
  value = aws_cloudtrail.main.name
}

output "config_rule_names" {
  value = [for r in aws_config_config_rule.managed : r.name]
}
