variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "csv_imports_expiration_days" {
  description = "Number of days before objects under csv_imports/ prefix expire"
  type        = number
  default     = 7
}

variable "originals_expiration_days" {
  description = "Number of days before objects under originals/ prefix expire"
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Allow bucket destruction even when it contains objects (use for dev only)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
