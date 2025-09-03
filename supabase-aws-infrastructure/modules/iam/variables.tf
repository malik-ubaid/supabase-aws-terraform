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

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for EKS cluster"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "OIDC provider URL for EKS cluster"
  type        = string
  default     = ""
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for Supabase storage"
  type        = string
  default     = ""
}

variable "secrets_manager_arns" {
  description = "List of Secrets Manager ARNs that services need access to"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}