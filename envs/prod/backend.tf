# Prod state is separate from dev: same bucket, different key
terraform {
  backend "s3" {
    bucket       = "secure-aws-platform-tfstate-211125360310"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
