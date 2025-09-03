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

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "node_groups" {
  description = "Configuration for EKS node groups"
  type = list(object({
    name             = string
    instance_types   = list(string)
    capacity_type    = string
    desired_size     = number
    max_size         = number
    min_size         = number
    max_unavailable  = optional(number, 1)
    disk_size        = optional(number, 50)
    ami_type         = optional(string, "AL2023_x86_64_STANDARD")
    labels           = optional(map(string), {})
    taints           = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = [
    {
      name           = "supabase-general"
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      max_size       = 5
      min_size       = 1
      disk_size      = 50
    },
    {
      name           = "supabase-spot"
      instance_types = ["t3.large", "m5.large", "m5a.large"]
      capacity_type  = "SPOT"
      desired_size   = 1
      max_size       = 10
      min_size       = 0
      disk_size      = 50
    }
  ]
}

variable "ec2_ssh_key" {
  description = "EC2 Key Pair name for SSH access to nodes"
  type        = string
  default     = null
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Initial storage allocation in GB"
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "Maximum storage allocation for autoscaling in GB"
  type        = number
  default     = 1000
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.8"
}

variable "db_backup_retention_period" {
  description = "Database backup retention period in days"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable database deletion protection"
  type        = bool
  default     = true
}

variable "s3_versioning_enabled" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_force_destroy" {
  description = "Allow S3 bucket to be destroyed even if it contains objects"
  type        = bool
  default     = false
}

variable "enable_performance_insights" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = true
}

variable "enable_enhanced_monitoring" {
  description = "Enable RDS Enhanced Monitoring"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds"
  type        = number
  default     = 60
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}