variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "supabase"
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster"
  type        = list(string)
}

variable "eks_cluster_role_arn" {
  description = "IAM role ARN for EKS cluster"
  type        = string
}

variable "eks_nodegroup_role_arn" {
  description = "IAM role ARN for EKS node groups"
  type        = string
}

variable "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  type        = string
  default     = null
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for cluster autoscaler"
  type        = string
  default     = null
}

variable "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  type        = string
  default     = null
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
    }
  ]
}

variable "ec2_ssh_key" {
  description = "EC2 Key Pair name for SSH access to nodes"
  type        = string
  default     = null
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

variable "cluster_enabled_log_types" {
  description = "List of cluster log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "Retention period for cluster logs in days"
  type        = number
  default     = 14
}

variable "enable_cluster_encryption" {
  description = "Enable envelope encryption for Kubernetes secrets"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}