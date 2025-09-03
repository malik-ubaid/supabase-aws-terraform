output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_nodegroup_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_nodegroup.arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the cluster autoscaler IAM role"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets Operator IAM role"
  value       = aws_iam_role.external_secrets.arn
}

output "supabase_storage_role_arn" {
  description = "ARN of the Supabase storage IAM role"
  value       = aws_iam_role.supabase_storage.arn
}

output "iam_role_arns" {
  description = "Map of all IAM role ARNs"
  value = {
    eks_cluster                 = aws_iam_role.eks_cluster.arn
    eks_nodegroup              = aws_iam_role.eks_nodegroup.arn
    ebs_csi_driver             = aws_iam_role.ebs_csi_driver.arn
    cluster_autoscaler         = aws_iam_role.cluster_autoscaler.arn
    aws_load_balancer_controller = aws_iam_role.aws_load_balancer_controller.arn
    external_secrets           = aws_iam_role.external_secrets.arn
    supabase_storage          = aws_iam_role.supabase_storage.arn
  }
}