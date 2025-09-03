variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  type        = string
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
  description = "VPC ID where EKS cluster is running"
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

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}