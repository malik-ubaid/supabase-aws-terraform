# Centralized Service Tier Configuration
# This should match the service_tier in core/terraform.tfvars

service_tier = "minimal"  # Options: minimal, small, medium, large, xlarge

# Basic Configuration
region       = "eu-west-1"
environment  = "development"
project_name = "supabase"

namespace = "supabase"

# Optional: External access configuration
external_url    = ""
certificate_arn = ""

# Feature toggles (can be overridden regardless of tier)
dashboard_enabled = true
auth_enabled      = true
storage_enabled   = true
realtime_enabled  = true

# All resource and scaling configurations are controlled by the service_tier variable
# See service-tiers.yaml for detailed tier specifications