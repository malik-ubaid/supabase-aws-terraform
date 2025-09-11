# Load centralized service tier configuration
locals {
  # Load service tier configurations from root
  service_tiers = yamldecode(file("${path.root}/../../service-tiers.yaml"))
  
  # Get current tier configuration
  current_tier = local.service_tiers.tiers[var.service_tier]
  
  # Supabase tier-specific configurations
  supabase_tier_config = {
    image_tag  = local.current_tier.supabase.image_tag
    enable_hpa = local.current_tier.supabase.enable_hpa
    
    # Resource configurations
    resource_requests = {
      kong      = local.current_tier.supabase.resources.kong.requests
      postgrest = local.current_tier.supabase.resources.postgrest.requests
      realtime  = local.current_tier.supabase.resources.realtime.requests
      auth      = local.current_tier.supabase.resources.auth.requests
      storage   = local.current_tier.supabase.resources.storage.requests
    }
    
    resource_limits = {
      kong      = local.current_tier.supabase.resources.kong.limits
      postgrest = local.current_tier.supabase.resources.postgrest.limits
      realtime  = local.current_tier.supabase.resources.realtime.limits
      auth      = local.current_tier.supabase.resources.auth.limits
      storage   = local.current_tier.supabase.resources.storage.limits
    }
    
    # HPA configuration (only if HPA is enabled)
    hpa_config = local.current_tier.supabase.enable_hpa ? try({
      postgrest = { min_replicas = local.current_tier.supabase.hpa.postgrest.min, max_replicas = local.current_tier.supabase.hpa.postgrest.max, cpu_target = local.current_tier.supabase.hpa.postgrest.cpu_target }
      realtime  = { min_replicas = local.current_tier.supabase.hpa.realtime.min, max_replicas = local.current_tier.supabase.hpa.realtime.max, cpu_target = local.current_tier.supabase.hpa.realtime.cpu_target }
      auth      = { min_replicas = local.current_tier.supabase.hpa.auth.min, max_replicas = local.current_tier.supabase.hpa.auth.max, cpu_target = local.current_tier.supabase.hpa.auth.cpu_target }
      storage   = { min_replicas = local.current_tier.supabase.hpa.storage.min, max_replicas = local.current_tier.supabase.hpa.storage.max, cpu_target = local.current_tier.supabase.hpa.storage.cpu_target }
    }, {
      postgrest = { min_replicas = 1, max_replicas = 3, cpu_target = 70 }
      realtime  = { min_replicas = 1, max_replicas = 3, cpu_target = 70 }
      auth      = { min_replicas = 1, max_replicas = 3, cpu_target = 70 }
      storage   = { min_replicas = 1, max_replicas = 3, cpu_target = 70 }
    }) : {
      postgrest = { min_replicas = 1, max_replicas = 1, cpu_target = 70 }
      realtime  = { min_replicas = 1, max_replicas = 1, cpu_target = 70 }
      auth      = { min_replicas = 1, max_replicas = 1, cpu_target = 70 }
      storage   = { min_replicas = 1, max_replicas = 1, cpu_target = 70 }
    }
  }
  
  # Cost information
  estimated_cost = local.current_tier.monthly_cost_estimate
  tier_description = local.current_tier.description
}