data "aws_caller_identity" "current" {}

module "iam" {
  source = "../../modules/iam"

  project_name   = var.project_name
  environment    = var.environment
  region         = var.region
  cluster_name   = local.cluster_name

  tags = {
    Owner = "Platform Team"
  }
}

module "iam_service_accounts" {
  source = "../../modules/iam"

  project_name   = var.project_name
  environment    = var.environment
  region         = var.region
  cluster_name   = local.cluster_name
  
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  s3_bucket_arn     = module.s3.bucket_arn
  secrets_manager_arns = module.secrets.all_secrets_arns
  
  create_cluster_roles = false
  create_service_account_roles = true

  tags = {
    Owner = "Platform Team"
  }

  depends_on = [module.eks]
}

module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  bucket_name               = "storage"
  versioning_enabled        = local.current_tier.s3.versioning_enabled
  force_destroy            = local.current_tier.s3.force_destroy
  enable_server_side_encryption = true
  enable_public_access_block = true
  enable_cors              = true
  enable_access_logging    = local.current_tier.s3.enable_access_logging

  tags = {
    Owner = "Platform Team"
    ServiceTier = var.service_tier
    EstimatedMonthlyCost = local.estimated_cost
  }
}

module "secrets" {
  source = "../../modules/secrets"

  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  external_database_url = module.rds.db_connection_string
  s3_bucket_name       = module.s3.bucket_id
  
  supabase_config = {
    site_url           = "http://localhost:3000"
    api_external_url   = "https://api.${var.project_name}-${var.environment}.example.com"
    dashboard_username = "admin"
    smtp_admin_email   = "admin@example.com"
    smtp_host         = "email-smtp.${var.region}.amazonaws.com"
    smtp_port         = 587
    smtp_user         = ""
  }

  tags = {
    Owner = "Platform Team"
    ServiceTier = var.service_tier
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = local.current_tier.eks.cluster_version
  region          = var.region
  environment     = var.environment
  project_name    = var.project_name
  
  vpc_id     = data.terraform_remote_state.networking.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.networking.outputs.eks_private_subnet_ids
  
  eks_cluster_role_arn               = module.iam.eks_cluster_role_arn
  eks_nodegroup_role_arn            = module.iam.eks_nodegroup_role_arn
  
  # Service account roles are not provided initially to avoid cycle
  # ebs_csi_driver_role_arn           = module.iam_service_accounts.ebs_csi_driver_role_arn
  # cluster_autoscaler_role_arn       = module.iam_service_accounts.cluster_autoscaler_role_arn
  # aws_load_balancer_controller_role_arn = module.iam_service_accounts.aws_load_balancer_controller_role_arn
  
  node_groups                       = local.tier_node_groups
  ec2_ssh_key                      = var.ec2_ssh_key
  
  cluster_endpoint_private_access   = local.current_tier.eks.endpoint_private_access
  cluster_endpoint_public_access    = local.current_tier.eks.endpoint_public_access
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  
  enable_cluster_encryption = true

  tags = {
    Owner = "Platform Team"
    ServiceTier = var.service_tier
    EstimatedMonthlyCost = local.estimated_cost
  }
}

# Temporarily disabled due to count argument issues
# Will be re-enabled after core infrastructure is deployed
# module "eks_addons" {
#   source = "../../modules/eks-addons"
#
#   cluster_name    = local.cluster_name
#   cluster_version = local.current_tier.eks.cluster_version
#   region          = var.region
#   environment     = var.environment
#   project_name    = var.project_name
#   vpc_id          = data.terraform_remote_state.networking.outputs.vpc_id
#
#   ebs_csi_driver_role_arn           = module.iam_service_accounts.ebs_csi_driver_role_arn
#   cluster_autoscaler_role_arn       = module.iam_service_accounts.cluster_autoscaler_role_arn
#   aws_load_balancer_controller_role_arn = module.iam_service_accounts.aws_load_balancer_controller_role_arn
#
#   tags = {
#     Owner = "Platform Team"
#     ServiceTier = var.service_tier
#     EstimatedMonthlyCost = local.estimated_cost
#   }
#
#   depends_on = [module.eks, module.iam_service_accounts]
# }

# Fargate Profile for serverless compute
resource "aws_iam_role" "fargate_pod_execution_role" {
  name = "${var.project_name}-${var.environment}-fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Owner = "Platform Team"
    ServiceTier = var.service_tier
    EstimatedMonthlyCost = local.estimated_cost
  }
}

resource "aws_iam_role_policy" "fargate_pod_execution_role_policy" {
  name = "${var.project_name}-${var.environment}-fargate-pod-execution-policy"
  role = aws_iam_role.fargate_pod_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_eks_fargate_profile" "supabase" {
  cluster_name           = module.eks.cluster_name
  fargate_profile_name   = "supabase-fargate"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn

  subnet_ids = data.terraform_remote_state.networking.outputs.eks_private_subnet_ids

  selector {
    namespace = "supabase"
  }

  selector {
    namespace = "external-secrets"
  }

  selector {
    namespace = "kube-system"
    labels = {
      "k8s-app" = "aws-load-balancer-controller"
    }
  }

  tags = {
    Owner = "Platform Team"
    ServiceTier = var.service_tier
    EstimatedMonthlyCost = local.estimated_cost
  }

  depends_on = [aws_iam_role_policy.fargate_pod_execution_role_policy]
}

module "rds" {
  source = "../../modules/rds"

  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  vpc_id               = data.terraform_remote_state.networking.outputs.vpc_id
  db_subnet_group_name = data.terraform_remote_state.networking.outputs.db_subnet_group_name
  
  allowed_security_group_ids = [module.eks.node_security_group_id]
  
  database_name   = "supabase"
  master_username = "supabase"
  engine_version  = local.current_tier.rds.engine_version
  instance_class  = local.current_tier.rds.instance_class
  
  allocated_storage     = local.current_tier.rds.allocated_storage
  max_allocated_storage = local.current_tier.rds.max_allocated_storage
  storage_type         = try(local.current_tier.rds.storage_type, "gp2")
  storage_iops         = local.current_tier.rds.allocated_storage < 400 ? null : try(local.current_tier.rds.storage_iops, null)
  storage_throughput   = local.current_tier.rds.allocated_storage < 400 ? null : try(local.current_tier.rds.storage_throughput, null)
  
  multi_az                = local.current_tier.rds.multi_az
  backup_retention_period = local.current_tier.rds.backup_retention_period
  deletion_protection     = local.current_tier.rds.deletion_protection
  
  performance_insights_enabled = local.current_tier.rds.performance_insights_enabled
  monitoring_interval         = local.current_tier.rds.monitoring_interval
  
  storage_encrypted = true
  skip_final_snapshot = true

  tags = {
    Owner = "Platform Team"
    ServiceTier = var.service_tier
    EstimatedMonthlyCost = local.estimated_cost
  }
}