# Dev state lives in the shared state bucket, under its own key.
# use_lockfile = S3-native state locking (no DynamoDB table needed).
terraform {
  backend "s3" {
    bucket       = "secure-aws-platform-tfstate-211125360310"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
