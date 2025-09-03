terraform {
  required_version = ">= 1.12"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }
  }
}

locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_eks_addon" "ebs_csi_driver" {
  count                       = var.ebs_csi_driver_role_arn != null ? 1 : 0
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi_driver[0].version
  service_account_role_arn    = var.ebs_csi_driver_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

data "aws_eks_addon_version" "ebs_csi_driver" {
  count              = var.ebs_csi_driver_role_arn != null ? 1 : 0
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

resource "helm_release" "cluster_autoscaler" {
  count      = var.cluster_autoscaler_role_arn != null ? 1 : 0
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.37.0"
  namespace  = "kube-system"

  values = [yamlencode({
    autoDiscovery = {
      clusterName = var.cluster_name
    }
    awsRegion = var.region
    rbac = {
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = var.cluster_autoscaler_role_arn
        }
        name = "cluster-autoscaler"
      }
    }
    extraArgs = {
      "scale-down-delay-after-add"  = "10m"
      "scale-down-unneeded-time"    = "10m"
    }
  })]
}

resource "helm_release" "aws_load_balancer_controller" {
  count      = var.aws_load_balancer_controller_role_arn != null ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = var.cluster_name
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.aws_load_balancer_controller_role_arn
      }
    }
    region = var.region
    vpcId  = var.vpc_id
  })]
}