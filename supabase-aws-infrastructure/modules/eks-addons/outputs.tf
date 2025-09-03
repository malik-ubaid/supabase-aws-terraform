output "ebs_csi_addon_status" {
  description = "Status of the EBS CSI addon"
  value       = var.ebs_csi_driver_role_arn != null ? "installed" : "not-installed"
}

output "cluster_autoscaler_status" {
  description = "Status of the cluster autoscaler Helm release"
  value       = var.cluster_autoscaler_role_arn != null ? "installed" : "not-installed"
}

output "aws_load_balancer_controller_status" {
  description = "Status of the AWS Load Balancer Controller Helm release"
  value       = var.aws_load_balancer_controller_role_arn != null ? "installed" : "not-installed"
}