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
variable "github_owner" {
  description = ""
  type        = string
  default     = "pallavir2590"
}

variable "github_repo" {
  description = "The GitHub repository name"
  type        = string
  default     = "secure-aws-platform"
}