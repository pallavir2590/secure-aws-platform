variable "project" {
  description = "Project name, used as a prefix for resource names"
  type        = string
}

variable "log_retention_days" {
  description = "How long to keep CloudTrail and AWS Config log files in S3"
  type        = number
  default     = 365
}
