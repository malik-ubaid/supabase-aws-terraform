# Central Variables File - Service Tier Control
# This file controls all infrastructure sizing through service tiers

variable "service_tier" {
  description = "Service tier for infrastructure sizing (minimal, small, medium, large, xlarge)"
  type        = string
  default     = "minimal"
  
  validation {
    condition = contains(["minimal", "small", "medium", "large", "xlarge"], var.service_tier)
    error_message = "Service tier must be one of: minimal, small, medium, large, xlarge."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "supabase"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
  
  validation {
    condition = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

# Network Configuration (consistent across tiers)
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.100.1.0/24", "10.100.2.0/24", "10.100.3.0/24"]
}

variable "eks_subnet_cidrs" {
  description = "CIDR blocks for EKS private subnets"
  type        = list(string)
  default     = ["10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"]
}

variable "rds_subnet_cidrs" {
  description = "CIDR blocks for RDS private subnets"
  type        = list(string)
  default     = ["10.100.20.0/24", "10.100.21.0/24", "10.100.22.0/24"]
}

# Optional overrides (use with caution)
variable "override_cluster_version" {
  description = "Override cluster version from service tier"
  type        = string
  default     = null
}

variable "override_rds_instance_class" {
  description = "Override RDS instance class from service tier"
  type        = string
  default     = null
}

variable "override_node_instance_types" {
  description = "Override node instance types from service tier"
  type        = list(string)
  default     = null
}

variable "ec2_ssh_key" {
  description = "EC2 Key Pair name for SSH access to nodes (optional)"
  type        = string
  default     = null
}

variable "external_url" {
  description = "External URL for Supabase API (leave empty for generated ALB URL)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "enable_dashboard" {
  description = "Enable Supabase dashboard"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default = {
    Owner       = "Platform Team"
    CostCenter  = "Engineering"
    Project     = "Supabase"
  }
}