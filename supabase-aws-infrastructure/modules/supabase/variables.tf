variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "supabase"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Supabase"
  type        = string
  default     = "supabase"
}

variable "create_namespace" {
  description = "Create the Kubernetes namespace"
  type        = bool
  default     = true
}

variable "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  type        = string
}

variable "supabase_storage_role_arn" {
  description = "IAM role ARN for Supabase storage access"
  type        = string
}

variable "secret_names" {
  description = "Map of AWS Secrets Manager secret names"
  type = object({
    jwt_secret        = string
    anon_key         = string
    service_role_key = string
    supabase_config  = string
  })
}

variable "database_config" {
  description = "Database connection configuration"
  type = object({
    host     = string
    port     = number
    database = string
    username = string
  })
}

variable "s3_config" {
  description = "S3 storage configuration"
  type = object({
    bucket_name = string
    region      = string
  })
}

variable "supabase_image_tag" {
  description = "Supabase image tag to deploy"
  type        = string
  default     = "latest"
}

variable "external_url" {
  description = "External URL for Supabase API"
  type        = string
  default     = ""
}

variable "dashboard_enabled" {
  description = "Enable Supabase dashboard"
  type        = bool
  default     = true
}

variable "auth_enabled" {
  description = "Enable Supabase Auth service"
  type        = bool
  default     = true
}

variable "storage_enabled" {
  description = "Enable Supabase Storage service"
  type        = bool
  default     = true
}

variable "realtime_enabled" {
  description = "Enable Supabase Realtime service"
  type        = bool
  default     = true
}

variable "enable_hpa" {
  description = "Enable Horizontal Pod Autoscaler"
  type        = bool
  default     = true
}

variable "hpa_config" {
  description = "HPA configuration for Supabase components"
  type = object({
    postgrest = object({
      min_replicas = number
      max_replicas = number
      cpu_target   = number
    })
    realtime = object({
      min_replicas = number
      max_replicas = number
      cpu_target   = number
    })
    auth = object({
      min_replicas = number
      max_replicas = number
      cpu_target   = number
    })
    storage = object({
      min_replicas = number
      max_replicas = number
      cpu_target   = number
    })
  })
  default = {
    postgrest = {
      min_replicas = 2
      max_replicas = 10
      cpu_target   = 70
    }
    realtime = {
      min_replicas = 2
      max_replicas = 5
      cpu_target   = 70
    }
    auth = {
      min_replicas = 2
      max_replicas = 5
      cpu_target   = 70
    }
    storage = {
      min_replicas = 2
      max_replicas = 5
      cpu_target   = 70
    }
  }
}

variable "resource_requests" {
  description = "Resource requests for Supabase components"
  type = object({
    postgrest = object({
      cpu    = string
      memory = string
    })
    realtime = object({
      cpu    = string
      memory = string
    })
    auth = object({
      cpu    = string
      memory = string
    })
    storage = object({
      cpu    = string
      memory = string
    })
    kong = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    postgrest = {
      cpu    = "100m"
      memory = "256Mi"
    }
    realtime = {
      cpu    = "100m"
      memory = "256Mi"
    }
    auth = {
      cpu    = "100m"
      memory = "256Mi"
    }
    storage = {
      cpu    = "100m"
      memory = "256Mi"
    }
    kong = {
      cpu    = "200m"
      memory = "512Mi"
    }
  }
}

variable "resource_limits" {
  description = "Resource limits for Supabase components"
  type = object({
    postgrest = object({
      cpu    = string
      memory = string
    })
    realtime = object({
      cpu    = string
      memory = string
    })
    auth = object({
      cpu    = string
      memory = string
    })
    storage = object({
      cpu    = string
      memory = string
    })
    kong = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    postgrest = {
      cpu    = "1000m"
      memory = "1Gi"
    }
    realtime = {
      cpu    = "1000m"
      memory = "1Gi"
    }
    auth = {
      cpu    = "500m"
      memory = "512Mi"
    }
    storage = {
      cpu    = "500m"
      memory = "512Mi"
    }
    kong = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "ingress_enabled" {
  description = "Enable ingress for Supabase"
  type        = bool
  default     = true
}

variable "ingress_class" {
  description = "Ingress class to use"
  type        = string
  default     = "alb"
}

variable "ingress_annotations" {
  description = "Additional annotations for ingress"
  type        = map(string)
  default     = {}
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}