# Load centralized service tier configuration
locals {
  # Load service tier configurations from root
  service_tiers = yamldecode(file("${path.root}/../../../../service-tiers.yaml"))
  
  # Get current tier configuration
  current_tier = local.service_tiers.tiers[var.service_tier]
  
  # Base configuration
  cluster_name = "${var.project_name}-${var.environment}-eks"
  
  # Tier-specific configurations
  tier_node_groups = [
    for ng in local.current_tier.eks.node_groups : {
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
        "workload"     = "supabase"
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
  
  # Cost information
  estimated_cost = local.current_tier.monthly_cost_estimate
  tier_description = local.current_tier.description
}