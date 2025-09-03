terraform {
  required_version = ">= 1.12"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
  }
}

locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_kms_key" "secrets" {
  count       = var.kms_key_id == null ? 1 : 0
  description = "KMS key for Secrets Manager encryption"
  
  enable_key_rotation = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-secrets-encryption-key"
  })
}

resource "aws_kms_alias" "secrets" {
  count         = var.kms_key_id == null ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "random_password" "anon_key" {
  length  = 64
  special = false
}

resource "random_password" "service_role_key" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}/${var.environment}/jwt-secret"
  description             = "JWT secret for Supabase authentication"
  kms_key_id             = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.secrets[0].arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-jwt-secret"
  })
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

resource "aws_secretsmanager_secret" "anon_key" {
  name                    = "${var.project_name}/${var.environment}/anon-key"
  description             = "Anonymous API key for Supabase"
  kms_key_id             = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.secrets[0].arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-anon-key"
  })
}

resource "aws_secretsmanager_secret_version" "anon_key" {
  secret_id     = aws_secretsmanager_secret.anon_key.id
  secret_string = random_password.anon_key.result
}

resource "aws_secretsmanager_secret" "service_role_key" {
  name                    = "${var.project_name}/${var.environment}/service-role-key"
  description             = "Service role API key for Supabase"
  kms_key_id             = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.secrets[0].arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-service-role-key"
  })
}

resource "aws_secretsmanager_secret_version" "service_role_key" {
  secret_id     = aws_secretsmanager_secret.service_role_key.id
  secret_string = random_password.service_role_key.result
}

resource "aws_secretsmanager_secret" "supabase_config" {
  name                    = "${var.project_name}/${var.environment}/config"
  description             = "Supabase application configuration"
  kms_key_id             = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.secrets[0].arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-config"
  })
}

resource "aws_secretsmanager_secret_version" "supabase_config" {
  secret_id = aws_secretsmanager_secret.supabase_config.id
  secret_string = jsonencode({
    site_url             = var.supabase_config.site_url
    api_external_url     = var.supabase_config.api_external_url
    database_url         = var.external_database_url
    s3_bucket           = var.s3_bucket_name
    s3_region           = var.region
    dashboard_username   = var.supabase_config.dashboard_username
    smtp_admin_email     = var.supabase_config.smtp_admin_email
    smtp_host           = var.supabase_config.smtp_host
    smtp_port           = var.supabase_config.smtp_port
    smtp_user           = var.supabase_config.smtp_user
  })
}

resource "aws_secretsmanager_secret" "additional" {
  for_each = var.additional_secrets

  name                    = "${var.project_name}/${var.environment}/${each.key}"
  description             = each.value.description
  kms_key_id             = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.secrets[0].arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}"
  })
}

resource "random_password" "additional" {
  for_each = {
    for k, v in var.additional_secrets : k => v
    if v.generate_secret == true
  }

  length  = each.value.secret_length
  special = true
}

resource "aws_secretsmanager_secret_version" "additional" {
  for_each = var.additional_secrets

  secret_id = aws_secretsmanager_secret.additional[each.key].id
  secret_string = each.value.generate_secret ? random_password.additional[each.key].result : each.value.secret_string
  secret_binary = each.value.secret_binary
}