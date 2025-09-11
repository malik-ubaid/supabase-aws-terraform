module "supabase" {
  source = "../../modules/supabase"

  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  cluster_name = data.terraform_remote_state.core.outputs.cluster_name
  namespace    = var.namespace
  
  external_secrets_role_arn  = data.terraform_remote_state.core.outputs.iam_role_arns.external_secrets
  supabase_storage_role_arn = data.terraform_remote_state.core.outputs.iam_role_arns.supabase_storage
  
  secret_names = data.terraform_remote_state.core.outputs.secret_names
  
  database_config = {
    host     = data.terraform_remote_state.core.outputs.database_endpoint
    port     = data.terraform_remote_state.core.outputs.database_port
    database = data.terraform_remote_state.core.outputs.database_name
    username = "supabase"
  }
  
  s3_config = {
    bucket_name = data.terraform_remote_state.core.outputs.s3_bucket_name
    region      = var.region
  }
  
  # Use tier-specific configurations
  supabase_image_tag = local.supabase_tier_config.image_tag
  external_url       = var.external_url
  certificate_arn    = var.certificate_arn
  
  dashboard_enabled = var.dashboard_enabled
  auth_enabled      = var.auth_enabled
  storage_enabled   = var.storage_enabled
  realtime_enabled  = var.realtime_enabled
  
  enable_hpa     = local.supabase_tier_config.enable_hpa
  hpa_config     = local.supabase_tier_config.hpa_config
  
  resource_requests = local.supabase_tier_config.resource_requests
  resource_limits   = local.supabase_tier_config.resource_limits
  
  ingress_enabled = true
  ingress_class   = "alb"
  
  ingress_annotations = {
    "alb.ingress.kubernetes.io/group.name"           = "${var.project_name}-${var.environment}"
    "alb.ingress.kubernetes.io/backend-protocol"     = "HTTP"
    "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
    "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
    "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"
    "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "2"
  }

  tags = {
    Owner = "Platform Team"
    ServiceTier = var.service_tier
    EstimatedMonthlyCost = local.estimated_cost
  }
}