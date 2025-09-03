terraform {
  required_version = ">= 1.12"
  
  required_providers {
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
  labels = {
    "app.kubernetes.io/name"       = "supabase"
    "app.kubernetes.io/instance"   = "${var.project_name}-${var.environment}"
    "app.kubernetes.io/version"    = var.supabase_image_tag
    "app.kubernetes.io/component"  = "backend"
    "app.kubernetes.io/part-of"    = var.project_name
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
  }

  ingress_annotations = merge({
    "kubernetes.io/ingress.class"                    = var.ingress_class
    "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"         = "ip"
    "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
    "alb.ingress.kubernetes.io/ssl-redirect"        = "443"
    "alb.ingress.kubernetes.io/healthcheck-path"    = "/health"
    "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
    "alb.ingress.kubernetes.io/group.name"         = "${var.project_name}-${var.environment}"
  }, var.certificate_arn != "" ? {
    "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
  } : {}, var.ingress_annotations)
}

resource "kubernetes_namespace" "supabase" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = merge(local.labels, {
      "name" = var.namespace
    })
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.11"
  namespace        = "external-secrets"
  create_namespace = true

  values = [
    yamlencode({
      installCRDs = true
      
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = var.external_secrets_role_arn
        }
      }
      
      tolerations = [
        {
          key      = "spot-instance"
          value    = "true"
          operator = "Equal"
          effect   = "NoSchedule"
        }
      ]
      
      webhook = {
        tolerations = [
          {
            key      = "spot-instance"
            value    = "true"
            operator = "Equal"
            effect   = "NoSchedule"
          }
        ]
      }
      
      certController = {
        tolerations = [
          {
            key      = "spot-instance"
            value    = "true"
            operator = "Equal"
            effect   = "NoSchedule"
          }
        ]
      }
    })
  ]
}

resource "kubernetes_service_account" "external_secrets" {
  metadata {
    name      = "external-secrets"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = var.external_secrets_role_arn
    }
    labels = local.labels
  }

  depends_on = [kubernetes_namespace.supabase]
}

resource "kubernetes_manifest" "secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "aws-secrets-manager"
      namespace = var.namespace
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name = kubernetes_service_account.external_secrets.metadata[0].name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "kubernetes_manifest" "supabase_secrets" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "supabase-secrets"
      namespace = var.namespace
    }
    spec = {
      secretStoreRef = {
        name = kubernetes_manifest.secret_store.manifest.metadata.name
        kind = "SecretStore"
      }
      target = {
        name = "supabase-secrets"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "jwt-secret"
          remoteRef = {
            key = var.secret_names.jwt_secret
          }
        },
        {
          secretKey = "anon-key"
          remoteRef = {
            key = var.secret_names.anon_key
          }
        },
        {
          secretKey = "service-role-key"
          remoteRef = {
            key = var.secret_names.service_role_key
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.secret_store]
}

resource "kubernetes_manifest" "supabase_config" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "supabase-config"
      namespace = var.namespace
    }
    spec = {
      secretStoreRef = {
        name = kubernetes_manifest.secret_store.manifest.metadata.name
        kind = "SecretStore"
      }
      target = {
        name = "supabase-config"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = var.secret_names.supabase_config
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.secret_store]
}

resource "kubernetes_service_account" "supabase_storage" {
  metadata {
    name      = "supabase-storage"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = var.supabase_storage_role_arn
    }
    labels = merge(local.labels, {
      "app.kubernetes.io/component" = "storage"
    })
  }

  depends_on = [kubernetes_namespace.supabase]
}

resource "kubernetes_config_map" "supabase_config" {
  metadata {
    name      = "supabase-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "POSTGRES_HOST"     = var.database_config.host
    "POSTGRES_PORT"     = tostring(var.database_config.port)
    "POSTGRES_DB"       = var.database_config.database
    "POSTGRES_USER"     = var.database_config.username
    "S3_BUCKET"         = var.s3_config.bucket_name
    "S3_REGION"         = var.s3_config.region
    "REGION"            = var.region
    "ENVIRONMENT"       = var.environment
  }

  depends_on = [kubernetes_namespace.supabase]
}

resource "helm_release" "supabase" {
  name      = "supabase"
  chart     = "${path.module}/../../helm-charts/supabase-custom"
  namespace = var.namespace
  
  timeout = 600
  wait    = true

  values = [
    templatefile("${path.module}/helm-values.yaml", {
      namespace                = var.namespace
      environment             = var.environment
      project_name            = var.project_name  
      external_url            = var.external_url
      database_host           = var.database_config.host
      database_port           = var.database_config.port
      database_name           = var.database_config.database
      s3_bucket              = var.s3_config.bucket_name
      s3_region              = var.s3_config.region
      image_tag              = var.supabase_image_tag
      enable_hpa             = var.enable_hpa
      storage_service_account = kubernetes_service_account.supabase_storage.metadata[0].name
      
      # Resource configurations
      postgrest_requests_cpu    = var.resource_requests.postgrest.cpu
      postgrest_requests_memory = var.resource_requests.postgrest.memory
      postgrest_limits_cpu      = var.resource_limits.postgrest.cpu
      postgrest_limits_memory   = var.resource_limits.postgrest.memory
      
      realtime_requests_cpu     = var.resource_requests.realtime.cpu
      realtime_requests_memory  = var.resource_requests.realtime.memory
      realtime_limits_cpu       = var.resource_limits.realtime.cpu
      realtime_limits_memory    = var.resource_limits.realtime.memory
      
      auth_requests_cpu         = var.resource_requests.auth.cpu
      auth_requests_memory      = var.resource_requests.auth.memory
      auth_limits_cpu           = var.resource_limits.auth.cpu
      auth_limits_memory        = var.resource_limits.auth.memory
      
      storage_requests_cpu      = var.resource_requests.storage.cpu
      storage_requests_memory   = var.resource_requests.storage.memory
      storage_limits_cpu        = var.resource_limits.storage.cpu
      storage_limits_memory     = var.resource_limits.storage.memory
      
      kong_requests_cpu         = var.resource_requests.kong.cpu
      kong_requests_memory      = var.resource_requests.kong.memory
      kong_limits_cpu           = var.resource_limits.kong.cpu
      kong_limits_memory        = var.resource_limits.kong.memory
      
      # HPA configurations
      postgrest_hpa_min = var.hpa_config.postgrest.min_replicas
      postgrest_hpa_max = var.hpa_config.postgrest.max_replicas
      postgrest_hpa_cpu = var.hpa_config.postgrest.cpu_target
      
      realtime_hpa_min = var.hpa_config.realtime.min_replicas
      realtime_hpa_max = var.hpa_config.realtime.max_replicas
      realtime_hpa_cpu = var.hpa_config.realtime.cpu_target
      
      auth_hpa_min = var.hpa_config.auth.min_replicas
      auth_hpa_max = var.hpa_config.auth.max_replicas
      auth_hpa_cpu = var.hpa_config.auth.cpu_target
      
      storage_hpa_min = var.hpa_config.storage.min_replicas
      storage_hpa_max = var.hpa_config.storage.max_replicas
      storage_hpa_cpu = var.hpa_config.storage.cpu_target
    })
  ]

  depends_on = [
    kubernetes_manifest.supabase_secrets,
    kubernetes_manifest.supabase_config,
    kubernetes_service_account.supabase_storage
  ]
}

resource "kubernetes_ingress_v1" "supabase" {
  count = var.ingress_enabled ? 1 : 0

  metadata {
    name        = "supabase-ingress"
    namespace   = var.namespace
    labels      = local.labels
    annotations = local.ingress_annotations
  }

  spec {
    ingress_class_name = var.ingress_class

    rule {
      host = var.external_url != "" ? replace(var.external_url, "https://", "") : null
      
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = "supabase-kong"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }

    dynamic "tls" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        hosts = [replace(var.external_url, "https://", "")]
      }
    }
  }

  depends_on = [helm_release.supabase]
}