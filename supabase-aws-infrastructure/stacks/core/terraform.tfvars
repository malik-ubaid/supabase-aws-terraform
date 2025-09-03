# Centralized Service Tier Configuration
# Change this single variable to control all infrastructure sizing and costs

service_tier = "small"  # Options: minimal, small, medium, large, xlarge

# Basic Configuration
region       = "eu-west-1"
environment  = "development"
project_name = "supabase"

# Optional: SSH key for debugging (leave null for security)
ec2_ssh_key = null

# Optional: External access configuration
# external_url = "https://api.supabase-dev.example.com"
# certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# All other configurations are controlled by the service_tier variable
# See service-tiers.yaml for detailed tier specifications