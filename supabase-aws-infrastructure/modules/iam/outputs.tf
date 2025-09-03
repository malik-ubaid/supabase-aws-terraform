output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = var.create_cluster_roles ? aws_iam_role.eks_cluster[0].arn : null
}

output "eks_nodegroup_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = var.create_cluster_roles ? aws_iam_role.eks_nodegroup[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = var.create_service_account_roles ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the cluster autoscaler IAM role"
  value       = var.create_service_account_roles ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = var.create_service_account_roles ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets Operator IAM role"
  value       = var.create_service_account_roles ? aws_iam_role.external_secrets[0].arn : null
}

output "supabase_storage_role_arn" {
  description = "ARN of the Supabase storage IAM role"
  value       = var.create_service_account_roles ? aws_iam_role.supabase_storage[0].arn : null
}

output "iam_role_arns" {
  description = "Map of all IAM role ARNs"
  value = {
    eks_cluster                 = var.create_cluster_roles ? aws_iam_role.eks_cluster[0].arn : null
    eks_nodegroup              = var.create_cluster_roles ? aws_iam_role.eks_nodegroup[0].arn : null
    ebs_csi_driver             = var.create_service_account_roles ? aws_iam_role.ebs_csi_driver[0].arn : null
    cluster_autoscaler         = var.create_service_account_roles ? aws_iam_role.cluster_autoscaler[0].arn : null
    aws_load_balancer_controller = var.create_service_account_roles ? aws_iam_role.aws_load_balancer_controller[0].arn : null
    external_secrets           = var.create_service_account_roles ? aws_iam_role.external_secrets[0].arn : null
    supabase_storage          = var.create_service_account_roles ? aws_iam_role.supabase_storage[0].arn : null
  }
}