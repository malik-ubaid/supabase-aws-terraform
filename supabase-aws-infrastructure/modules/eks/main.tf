terraform {
  required_version = ">= 1.12"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  cluster_name = var.cluster_name
  common_tags = merge(
    {
      Environment     = var.environment
      Project         = var.project_name
      ManagedBy       = "Terraform"
      KubernetesCluster = local.cluster_name
    },
    var.tags
  )
}

resource "aws_kms_key" "eks" {
  count       = var.enable_cluster_encryption ? 1 : 0
  description = "EKS Secret Encryption Key for ${local.cluster_name}"
  
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-encryption-key"
  })
}

resource "aws_kms_alias" "eks" {
  count         = var.enable_cluster_encryption ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-logs"
  })
}

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = var.eks_cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  dynamic "encryption_config" {
    for_each = var.enable_cluster_encryption ? [1] : []
    content {
      provider {
        key_arn = aws_kms_key.eks[0].arn
      }
      resources = ["secrets"]
    }
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })

  depends_on = [aws_cloudwatch_log_group.cluster]
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-oidc"
  })
}

resource "aws_security_group" "node_group" {
  name_prefix = "${var.project_name}-${var.environment}-eks-nodes-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS node groups"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-nodes-sg"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  })
}

resource "aws_security_group_rule" "node_group_ssh" {
  count             = var.ec2_ssh_key != null ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.cluster.cidr_block]
  description       = "SSH access from VPC"
  security_group_id = aws_security_group.node_group.id
}

data "aws_vpc" "cluster" {
  id = var.vpc_id
}

resource "aws_launch_template" "node_group" {
  count       = length(var.node_groups)
  name_prefix = "${var.node_groups[count.index].name}-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.node_groups[count.index].disk_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 150
      encrypted             = true
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [
    aws_security_group.node_group.id,
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  ]

  key_name = var.ec2_ssh_key

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.node_groups[count.index].name}-node"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${var.node_groups[count.index].name}-launch-template"
  })
}

resource "aws_eks_node_group" "main" {
  count           = length(var.node_groups)
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_groups[count.index].name
  node_role_arn   = var.eks_nodegroup_role_arn
  subnet_ids      = var.subnet_ids

  capacity_type  = var.node_groups[count.index].capacity_type
  instance_types = var.node_groups[count.index].instance_types
  ami_type       = var.node_groups[count.index].ami_type

  scaling_config {
    desired_size = var.node_groups[count.index].desired_size
    max_size     = var.node_groups[count.index].max_size
    min_size     = var.node_groups[count.index].min_size
  }

  update_config {
    max_unavailable = var.node_groups[count.index].max_unavailable
  }

  launch_template {
    id      = aws_launch_template.node_group[count.index].id
    version = aws_launch_template.node_group[count.index].latest_version
  }

  labels = merge({
    "node-group" = var.node_groups[count.index].name
    "capacity-type" = var.node_groups[count.index].capacity_type
  }, var.node_groups[count.index].labels)

  dynamic "taint" {
    for_each = var.node_groups[count.index].taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.node_groups[count.index].name}"
  })

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "kube-proxy"
  addon_version            = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "coredns"
  addon_version            = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  count                       = var.ebs_csi_driver_role_arn != null ? 1 : 0
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi_driver.version
  service_account_role_arn    = var.ebs_csi_driver_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

