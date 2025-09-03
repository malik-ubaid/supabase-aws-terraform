output "supabase_namespace" {
  description = "Kubernetes namespace where Supabase is deployed"
  value       = module.supabase.namespace
}

output "helm_release_name" {
  description = "Name of the Supabase Helm release"
  value       = module.supabase.helm_release_name
}

output "helm_release_status" {
  description = "Status of the Supabase Helm release"
  value       = module.supabase.helm_release_status
}

output "external_secrets_release_name" {
  description = "Name of the External Secrets Helm release"
  value       = module.supabase.external_secrets_release_name
}

output "api_url" {
  description = "Supabase API URL"
  value       = module.supabase.api_url
}

output "ingress_hostname" {
  description = "Hostname of the Supabase ingress"
  value       = module.supabase.ingress_hostname
}

output "service_account_names" {
  description = "Names of created service accounts"
  value       = module.supabase.service_account_names
}