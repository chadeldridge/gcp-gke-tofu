variable "region" {
  type = string
  description = "GCP Region for the application and supporting infrastructure"
  default = "us-central1"
}

variable "env" {
  type = string
  description = "Environment name"
}

variable "app_name" {
  type = string
  description = "Application name"
}

variable "untagged_keep_days" {
  type = number
  description = "Number of days to keep untagged images"
  default = 5
}

variable "versions_keep_count" {
  type = number
  description = "Number of most recent versions to keep"
  default = 5
}
