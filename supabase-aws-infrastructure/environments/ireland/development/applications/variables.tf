variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "supabase"
}

variable "service_tier" {
  description = "Service tier for infrastructure sizing (minimal, small, medium, large, xlarge)"
  type        = string
  default     = "minimal"
  
  validation {
    condition = contains(["minimal", "small", "medium", "large", "xlarge"], var.service_tier)
    error_message = "Service tier must be one of: minimal, small, medium, large, xlarge."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for Supabase"
  type        = string
  default     = "supabase"
}

variable "supabase_image_tag" {
  description = "Supabase image tag to deploy"
  type        = string
  default     = "latest"
}

variable "external_url" {
  description = "External URL for Supabase API"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "enable_hpa" {
  description = "Enable Horizontal Pod Autoscaler"
  type        = bool
  default     = true
}

variable "dashboard_enabled" {
  description = "Enable Supabase dashboard"
  type        = bool
  default     = true
}

variable "auth_enabled" {
  description = "Enable Supabase Auth service"
  type        = bool
  default     = true
}

variable "storage_enabled" {
  description = "Enable Supabase Storage service"
  type        = bool
  default     = true
}

variable "realtime_enabled" {
  description = "Enable Supabase Realtime service"
  type        = bool
  default     = true
}