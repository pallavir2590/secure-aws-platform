
output "state_bucket_name" {
  description = "Use this bucket name in the backend.tf files for dev and prod"
  value       = aws_s3_bucket.tfstate.bucket
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}