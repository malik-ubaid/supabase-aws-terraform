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

resource "random_password" "master_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}/${var.environment}/database/credentials"
  description = "Database credentials for ${var.project_name} ${var.environment}"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master_password.result
    endpoint = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = var.database_name
    url      = aws_db_instance.main.endpoint != null ? "postgresql://${var.master_username}:${random_password.master_password.result}@${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${var.database_name}" : ""
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS PostgreSQL instance"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "PostgreSQL access from allowed security groups"
  }

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "PostgreSQL access from allowed CIDR blocks"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  })
}

resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project_name}-${var.environment}-postgres-params"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pg_cron"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_checkpoints"
    value = "1"
  }

  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "effective_cache_size"
    value = "1048576"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-postgres-params"
  })
}

resource "aws_db_option_group" "main" {
  name                 = "${var.project_name}-${var.environment}-postgres-options"
  option_group_description = "Option group for ${var.project_name} PostgreSQL"
  engine_name          = "postgres"
  major_engine_version = split(".", var.engine_version)[0]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-postgres-options"
  })
}

resource "aws_kms_key" "rds" {
  count       = var.storage_encrypted && var.kms_key_id == null ? 1 : 0
  description = "KMS key for RDS encryption"
  
  enable_key_rotation = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-encryption-key"
  })
}

resource "aws_kms_alias" "rds" {
  count         = var.storage_encrypted && var.kms_key_id == null ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

resource "aws_iam_role" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.project_name}-${var.environment}-rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-postgresql"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  iops                  = var.storage_type == "gp3" || var.storage_type == "io1" || var.storage_type == "io2" ? var.storage_iops : null
  storage_throughput    = var.storage_type == "gp3" ? var.storage_throughput : null
  storage_encrypted     = var.storage_encrypted
  kms_key_id           = var.storage_encrypted ? (var.kms_key_id != null ? var.kms_key_id : aws_kms_key.rds[0].arn) : null

  db_name  = var.database_name
  username = var.master_username
  password = random_password.master_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = var.db_subnet_group_name
  parameter_group_name   = aws_db_parameter_group.main.name
  option_group_name      = aws_db_option_group.main.name

  multi_az               = var.multi_az
  publicly_accessible    = false
  
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  deletion_protection       = var.deletion_protection
  skip_final_snapshot      = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  copy_tags_to_snapshot    = var.copy_tags_to_snapshot

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  allow_major_version_upgrade = var.allow_major_version_upgrade
  apply_immediately          = var.apply_immediately

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-postgresql"
  })

  lifecycle {
    ignore_changes = [
      password,
      final_snapshot_identifier
    ]
  }
}