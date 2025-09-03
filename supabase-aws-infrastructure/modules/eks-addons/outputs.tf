output "ebs_csi_addon_status" {
  description = "Status of the EBS CSI addon"
  value       = var.ebs_csi_driver_role_arn != null ? aws_eks_addon.ebs_csi_driver[0].status : "not-installed"
}

output "cluster_autoscaler_status" {
  description = "Status of the cluster autoscaler Helm release"
  value       = var.cluster_autoscaler_role_arn != null ? helm_release.cluster_autoscaler[0].status : "not-installed"
}

output "aws_load_balancer_controller_status" {
  description = "Status of the AWS Load Balancer Controller Helm release"
  value       = var.aws_load_balancer_controller_role_arn != null ? helm_release.aws_load_balancer_controller[0].status : "not-installed"
}