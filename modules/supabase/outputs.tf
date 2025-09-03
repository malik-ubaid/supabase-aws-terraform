output "namespace" {
  description = "Kubernetes namespace where Supabase is deployed"
  value       = var.namespace
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.supabase.name
}

output "helm_release_namespace" {
  description = "Namespace of the Helm release"
  value       = helm_release.supabase.namespace
}

output "helm_release_version" {
  description = "Version of the Helm release"
  value       = helm_release.supabase.version
}

output "helm_release_status" {
  description = "Status of the Helm release"
  value       = helm_release.supabase.status
}

output "external_secrets_release_name" {
  description = "Name of the External Secrets Helm release"
  value       = helm_release.external_secrets.name
}

output "service_account_names" {
  description = "Names of created service accounts"
  value = {
    external_secrets = kubernetes_service_account.external_secrets.metadata[0].name
    supabase_storage = kubernetes_service_account.supabase_storage.metadata[0].name
  }
}

output "secret_store_name" {
  description = "Name of the External Secrets SecretStore"
  value       = kubernetes_manifest.secret_store.manifest.metadata.name
}

output "external_secret_names" {
  description = "Names of External Secrets created"
  value = {
    supabase_secrets = kubernetes_manifest.supabase_secrets.manifest.metadata.name
    supabase_config  = kubernetes_manifest.supabase_config.manifest.metadata.name
  }
}

output "config_map_name" {
  description = "Name of the Supabase ConfigMap"
  value       = kubernetes_config_map.supabase_config.metadata[0].name
}

output "ingress_hostname" {
  description = "Hostname of the Supabase ingress"
  value       = var.ingress_enabled && var.external_url != "" ? replace(var.external_url, "https://", "") : null
}

output "api_url" {
  description = "Supabase API URL"
  value       = var.external_url != "" ? "${var.external_url}/rest/v1" : null
}