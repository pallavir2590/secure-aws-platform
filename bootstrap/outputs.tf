
output "state_bucket_name" {
  description = "Use this bucket name in the backend.tf files for dev and prod"
  value       = aws_s3_bucket.tfstate.bucket
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "github_plan_role_arn" {
  description = "Add as GitHub secret AWS_PLAN_ROLE_ARN"
  value       = aws_iam_role.github_plan.arn
}

output "github_apply_role_arn" {
  description = "Add as GitHub secret AWS_APPLY_ROLE_ARN"
  value       = aws_iam_role.github_apply.arn
}