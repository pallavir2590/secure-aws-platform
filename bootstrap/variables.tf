variable "region" {
  description = "AWS region for the Terraform state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name, used in resource names"
  type        = string
  default     = "secure-aws-platform"
}