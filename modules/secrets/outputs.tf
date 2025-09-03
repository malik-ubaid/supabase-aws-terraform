output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "anon_key_secret_arn" {
  description = "ARN of the anonymous key secret"
  value       = aws_secretsmanager_secret.anon_key.arn
}

output "service_role_key_secret_arn" {
  description = "ARN of the service role key secret"
  value       = aws_secretsmanager_secret.service_role_key.arn
}

output "supabase_config_secret_arn" {
  description = "ARN of the Supabase configuration secret"
  value       = aws_secretsmanager_secret.supabase_config.arn
}

output "additional_secrets_arns" {
  description = "ARNs of additional secrets"
  value = {
    for k, v in aws_secretsmanager_secret.additional : k => v.arn
  }
}

output "all_secrets_arns" {
  description = "List of all secret ARNs created by this module"
  value = concat(
    [
      aws_secretsmanager_secret.jwt_secret.arn,
      aws_secretsmanager_secret.anon_key.arn,
      aws_secretsmanager_secret.service_role_key.arn,
      aws_secretsmanager_secret.supabase_config.arn
    ],
    values(aws_secretsmanager_secret.additional)[*].arn
  )
}

output "kms_key_id" {
  description = "KMS key ID used for encrypting secrets"
  value       = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.secrets[0].key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for encrypting secrets"
  value       = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.secrets[0].arn
}

output "secret_names" {
  description = "Map of secret names for reference"
  value = merge(
    {
      jwt_secret        = aws_secretsmanager_secret.jwt_secret.name
      anon_key         = aws_secretsmanager_secret.anon_key.name
      service_role_key = aws_secretsmanager_secret.service_role_key.name
      supabase_config  = aws_secretsmanager_secret.supabase_config.name
    },
    {
      for k, v in aws_secretsmanager_secret.additional : k => v.name
    }
  )
}