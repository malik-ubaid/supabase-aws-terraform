output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for the EKS cluster"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "The URL of the OIDC Provider for the EKS cluster"
  value       = module.eks.oidc_provider_url
}

output "node_groups" {
  description = "EKS node groups information"
  value       = module.eks.node_groups
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "database_port" {
  description = "RDS instance port"
  value       = module.rds.db_instance_port
}

output "database_name" {
  description = "Database name"
  value       = module.rds.db_instance_name
}

output "database_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = module.rds.db_credentials_secret_arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for Supabase storage"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.s3.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = module.s3.bucket_domain_name
}

output "secrets_arns" {
  description = "Map of all Secrets Manager ARNs"
  value = {
    jwt_secret        = module.secrets.jwt_secret_arn
    anon_key         = module.secrets.anon_key_secret_arn
    service_role_key = module.secrets.service_role_key_secret_arn
    supabase_config  = module.secrets.supabase_config_secret_arn
  }
}

output "secret_names" {
  description = "Map of secret names for reference"
  value       = module.secrets.secret_names
}

output "iam_role_arns" {
  description = "Map of all IAM role ARNs"
  value       = merge(
    module.iam.iam_role_arns,
    module.iam_service_accounts.iam_role_arns
  )
}

output "kubeconfig" {
  description = "kubectl config for the EKS cluster"
  value       = module.eks.kubeconfig
  sensitive   = true
}