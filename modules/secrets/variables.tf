variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "supabase"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting secrets"
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Recovery window for deleted secrets"
  type        = number
  default     = 7
}

variable "enable_automatic_rotation" {
  description = "Enable automatic rotation for applicable secrets"
  type        = bool
  default     = false
}

variable "rotation_days" {
  description = "Number of days for automatic rotation"
  type        = number
  default     = 30
}

variable "external_database_url" {
  description = "External database URL (from RDS module)"
  type        = string
  default     = ""
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storage configuration"
  type        = string
  default     = ""
}

variable "supabase_config" {
  description = "Supabase configuration values"
  type = object({
    site_url           = optional(string, "http://localhost:3000")
    api_external_url   = optional(string, "http://localhost:8000")
    dashboard_username = optional(string, "supabase")
    smtp_admin_email   = optional(string, "admin@example.com")
    smtp_host         = optional(string, "smtp.amazonaws.com")
    smtp_port         = optional(number, 587)
    smtp_user         = optional(string, "")
  })
  default = {}
}

variable "additional_secrets" {
  description = "Additional secrets to create"
  type = map(object({
    description = string
    secret_string = optional(string)
    secret_binary = optional(string)
    generate_secret = optional(bool, false)
    secret_length = optional(number, 32)
  }))
  default = {}
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}