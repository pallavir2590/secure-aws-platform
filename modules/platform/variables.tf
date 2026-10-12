variable "project" {
  description = "Project name, used as a prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name: dev or prod"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "alert_email" {
  description = "Email address that receives CloudWatch alarm notifications (leave empty to skip)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "How long to keep Lambda logs"
  type        = number
  default     = 365
}
