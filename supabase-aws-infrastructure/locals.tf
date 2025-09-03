# Centralized Service Tier Configuration
# This file loads service tier configurations and makes them available to all environments

locals {
  # Load service tier configurations
  service_tiers = yamldecode(file("${path.root}/service-tiers.yaml"))
  
  # Get current tier configuration
  current_tier_config = local.service_tiers.tiers[var.service_tier]
  
  # Validate service tier
  valid_tiers = keys(local.service_tiers.tiers)
  
  # Common configuration across all tiers
  common_config = {
    project_name = var.project_name
    environment  = var.environment
    region       = var.region
    
    # Network configuration (consistent across tiers)
    vpc_cidr = var.vpc_cidr
    availability_zones = var.availability_zones
    public_subnet_cidrs = var.public_subnet_cidrs
    eks_subnet_cidrs = var.eks_subnet_cidrs
    rds_subnet_cidrs = var.rds_subnet_cidrs
  }
  
  # Tier-specific EKS configuration
  eks_config = merge(local.common_config, {
    cluster_name    = "${var.project_name}-${var.environment}-eks"
    cluster_version = local.current_tier_config.eks.cluster_version
    node_groups     = [
      for ng in local.current_tier_config.eks.node_groups : {
        name             = ng.name
        instance_types   = ng.instance_types
        capacity_type    = ng.capacity_type
        desired_size     = ng.desired_size
        max_size         = ng.max_size
        min_size         = ng.min_size
        disk_size        = ng.disk_size
        ami_type         = "AL2023_x86_64_STANDARD"
        max_unavailable  = 1
        labels = {
          "service-tier" = var.service_tier
          "node-type"    = ng.capacity_type == "SPOT" ? "spot" : "on-demand"
        }
        taints = ng.capacity_type == "SPOT" ? [
          {
            key    = "spot-instance"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        ] : []
      }
    ]
    cluster_endpoint_private_access      = local.current_tier_config.eks.endpoint_private_access
    cluster_endpoint_public_access       = local.current_tier_config.eks.endpoint_public_access
    cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  })
  
  # Tier-specific RDS configuration
  rds_config = merge(local.common_config, {
    instance_class                = local.current_tier_config.rds.instance_class
    allocated_storage            = local.current_tier_config.rds.allocated_storage
    max_allocated_storage        = local.current_tier_config.rds.max_allocated_storage
    engine_version              = local.current_tier_config.rds.engine_version
    multi_az                    = local.current_tier_config.rds.multi_az
    backup_retention_period     = local.current_tier_config.rds.backup_retention_period
    deletion_protection         = local.current_tier_config.rds.deletion_protection
    performance_insights_enabled = local.current_tier_config.rds.performance_insights_enabled
    monitoring_interval         = local.current_tier_config.rds.monitoring_interval
    
    # Storage configuration based on tier
    storage_type       = local.current_tier_config.rds.instance_class == "db.t3.micro" ? "gp2" : "gp3"
    storage_iops       = local.current_tier_config.rds.instance_class == "db.t3.micro" ? null : 3000
    storage_throughput = local.current_tier_config.rds.instance_class == "db.t3.micro" ? null : 125
  })
  
  # Tier-specific S3 configuration
  s3_config = merge(local.common_config, {
    versioning_enabled    = local.current_tier_config.s3.versioning_enabled
    force_destroy        = local.current_tier_config.s3.force_destroy
    enable_access_logging = local.current_tier_config.s3.enable_access_logging
  })
  
  # Tier-specific Supabase configuration
  supabase_config = merge(local.common_config, {
    image_tag  = local.current_tier_config.supabase.image_tag
    enable_hpa = local.current_tier_config.supabase.enable_hpa
    
    # Resource configurations
    resource_requests = {
      kong      = local.current_tier_config.supabase.resources.kong.requests
      postgrest = local.current_tier_config.supabase.resources.postgrest.requests
      realtime  = local.current_tier_config.supabase.resources.realtime.requests
      auth      = local.current_tier_config.supabase.resources.auth.requests
      storage   = local.current_tier_config.supabase.resources.storage.requests
    }
    
    resource_limits = {
      kong      = local.current_tier_config.supabase.resources.kong.limits
      postgrest = local.current_tier_config.supabase.resources.postgrest.limits
      realtime  = local.current_tier_config.supabase.resources.realtime.limits
      auth      = local.current_tier_config.supabase.resources.auth.limits
      storage   = local.current_tier_config.supabase.resources.storage.limits
    }
    
    replicas = local.current_tier_config.supabase.replicas
    
    # HPA configuration (only if HPA is enabled)
    hpa_config = local.current_tier_config.supabase.enable_hpa ? try(local.current_tier_config.supabase.hpa, {
      postgrest = { min_replicas = 1, max_replicas = 3, cpu_target = 70 }
      realtime  = { min_replicas = 1, max_replicas = 3, cpu_target = 70 }
      auth      = { min_replicas = 1, max_replicas = 3, cpu_target = 70 }
      storage   = { min_replicas = 1, max_replicas = 3, cpu_target = 70 }
    }) : null
  })
  
  # Cost estimation
  estimated_monthly_cost = local.current_tier_config.monthly_cost_estimate
  tier_description = local.current_tier_config.description
}