# Supabase AWS Infrastructure - Configuration Guide

## 🎯 Configuration Overview

This guide covers all configuration aspects of the Supabase AWS infrastructure, from service tiers to environment-specific settings and customization options.

## 📁 Configuration Files Structure

```
supabase-aws-infrastructure/
├── service-tiers.yaml                    # Central service tier definitions
├── environments/ireland/development/
│   ├── networking/terraform.tfvars       # Networking configuration
│   ├── core/terraform.tfvars            # Core infrastructure config
│   └── applications/terraform.tfvars    # Application-specific config
├── modules/*/variables.tf               # Module input variables
└── helm-charts/supabase-custom/values.yaml  # Helm chart values
```

## 🎛️ Service Tier Configuration

### Current Implementation: Small Tier
The infrastructure is configured with the **Small** service tier, defined in `service-tiers.yaml`:

```yaml
small:
  description: "Small production setup for low-traffic applications"
  monthly_cost_estimate: "$150-250"
  use_cases: ["small production", "staging", "demos"]
  
  eks:
    cluster_version: "1.30"
    endpoint_private_access: true
    endpoint_public_access: true
    node_groups:
      - name: "small-general"
        instance_types: ["t3.medium"]
        capacity_type: "ON_DEMAND"
        desired_size: 2
        max_size: 4
        min_size: 1
  
  rds:
    instance_class: "db.t3.small"
    allocated_storage: 50
    max_allocated_storage: 500
    engine_version: "15.8"
    multi_az: false
    backup_retention_period: 3
  
  supabase:
    image_tag: "latest"
    enable_hpa: true
    resources:
      kong:
        requests: { cpu: "100m", memory: "256Mi" }
        limits: { cpu: "500m", memory: "512Mi" }
      postgrest:
        requests: { cpu: "100m", memory: "256Mi" }
        limits: { cpu: "500m", memory: "512Mi" }
    hpa:
      postgrest: { min: 2, max: 5, cpu_target: 70 }
      realtime: { min: 2, max: 4, cpu_target: 70 }
```

### Changing Service Tiers

```bash
# View current tier
cat environments/ireland/development/core/terraform.tfvars
# Output: service_tier = "small"

# Change to minimal tier (cost-optimized)
echo 'service_tier = "minimal"' > environments/ireland/development/core/terraform.tfvars

# Apply changes
cd environments/ireland/development/core
terraform plan
terraform apply
```

## 🌍 Environment Configuration

### Current Environment: Development (Ireland)
Location: `environments/ireland/development/`

#### Core Configuration (`core/terraform.tfvars`)
```hcl
# Service Tier Control
service_tier = "small"  # Options: minimal, small, medium, large, xlarge

# Basic Configuration
region       = "eu-west-1"
environment  = "development"
project_name = "supabase"

# Optional: SSH key for debugging (null for production security)
ec2_ssh_key = null

# Optional: External access configuration
# external_url = "https://api.supabase-dev.example.com"
# certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/xxx"
```

#### Networking Configuration (`networking/terraform.tfvars`)
```hcl
# Network addressing
vpc_cidr = "10.0.0.0/16"

# Subnet configurations (automatically calculated from service tier)
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
eks_subnet_cidrs    = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]  
rds_subnet_cidrs    = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]

# NAT Gateway configuration
enable_nat_gateway = true
single_nat_gateway = false  # false = one NAT per AZ (higher availability)

# VPC endpoints for cost optimization
enable_flow_logs = true
```

#### Applications Configuration (`applications/terraform.tfvars`)
```hcl
# Ingress configuration
ingress_enabled = true
ingress_class   = "alb"

# Custom domain (optional)
# external_url = "https://api.supabase-dev.example.com"
# certificate_arn = "arn:aws:acm:eu-west-1:account:certificate/xxx"

# Resource overrides (if needed)
# enable_dashboard = true
# enable_monitoring = true
```

## 🔧 Module Configuration

### EKS Module Configuration
Configured via service tiers and environment variables:

```hcl
# Current EKS configuration (from small tier)
cluster_version = "1.30"
node_groups = [
  {
    name           = "small-general"
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 2
    max_size       = 4
    min_size       = 1
    disk_size      = 30
  }
]

# Security configuration
cluster_endpoint_private_access = true
cluster_endpoint_public_access  = true
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
enable_cluster_encryption = true
```

### RDS Module Configuration
```hcl
# Current RDS configuration (from small tier)
database_name   = "supabase"
master_username = "supabase"
instance_class  = "db.t3.small"
engine_version  = "15.8"

# Storage configuration
allocated_storage     = 50
max_allocated_storage = 500
storage_type         = "gp3"
storage_encrypted    = true

# Backup and maintenance
backup_retention_period = 3
backup_window          = "03:00-04:00"
maintenance_window     = "sun:04:00-sun:05:00"
deletion_protection    = true

# Performance and monitoring
performance_insights_enabled = true
monitoring_interval         = 0  # Disabled for small tier
```

### S3 Module Configuration
```hcl
# Current S3 configuration
bucket_name               = "storage"
versioning_enabled        = true
force_destroy            = false
enable_server_side_encryption = true
enable_public_access_block = true
enable_cors              = true
enable_access_logging    = true

# Lifecycle policies for cost optimization
lifecycle_rules = [
  {
    id     = "transition_to_ia"
    status = "Enabled"
    transition = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      },
      {
        days          = 90
        storage_class = "GLACIER"
      }
    ]
  }
]
```

## 🐳 Helm Chart Configuration

### Supabase Custom Helm Chart
Location: `helm-charts/supabase-custom/values.yaml`

#### Current Configuration Highlights
```yaml
# Global settings
global:
  imageRegistry: ""
  imagePullSecrets: []

# Kong API Gateway
kong:
  enabled: true
  replicaCount: 2
  image:
    repository: kong
    tag: "3.4"
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi

# PostgREST
postgrest:
  enabled: true
  replicaCount: 2
  image:
    repository: postgrest/postgrest
    tag: "v12.0.2"
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi

# Horizontal Pod Autoscaler
autoscaling:
  enabled: true
  postgrest:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 70
  realtime:
    enabled: true
    minReplicas: 2
    maxReplicas: 4
    targetCPUUtilizationPercentage: 70

# Security contexts
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

# Database Configuration (External RDS)
database:
  external: true
  host: ""  # Populated by Terraform
  port: 5432
  name: "supabase"
  user: "supabase"

# Storage Configuration (External S3)
storageBackend:
  type: "s3"
  s3:
    bucket: ""     # Populated by Terraform
    region: "eu-west-1"
```

## 🔐 Secrets Configuration

### AWS Secrets Manager Integration
The infrastructure uses AWS Secrets Manager with External Secrets Operator for secure secret management:

#### Database Secrets
```json
{
  "username": "supabase",
  "password": "<auto-generated-32-char-password>",
  "endpoint": "<rds-endpoint>",
  "port": 5432,
  "dbname": "supabase",
  "url": "postgresql://supabase:<password>@<endpoint>:5432/supabase"
}
```

#### Supabase Configuration Secrets
```json
{
  "jwt_secret": "<auto-generated-256-bit-key>",
  "anon_key": "<generated-jwt-token>",
  "service_role_key": "<generated-service-jwt-token>",
  "site_url": "http://localhost:3000",
  "api_external_url": "https://api.supabase-development.example.com"
}
```

### Secret Access Pattern
```yaml
# External Secret definition
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: supabase-secrets
  namespace: supabase
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: supabase-secrets
    creationPolicy: Owner
  data:
    - secretKey: jwt-secret
      remoteRef:
        key: supabase/development/jwt-secret
    - secretKey: anon-key
      remoteRef:
        key: supabase/development/anon-key
```

## 🏷️ Tagging Strategy

### Resource Tagging
All resources are tagged consistently for cost allocation and management:

```hcl
common_tags = {
  Environment     = "development"
  Project         = "supabase"
  ManagedBy       = "Terraform"
  ServiceTier     = "small"
  Owner           = "Platform Team"
  CostCenter      = "Engineering"
  BackupPolicy    = "daily"
}

# EKS-specific tags
eks_tags = {
  "kubernetes.io/cluster/supabase-development-eks" = "owned"
}

# RDS-specific tags
rds_tags = {
  BackupRetention = "3-days"
  MaintenanceWindow = "sunday-04:00"
}
```

## 🔧 Customization Options

### Environment-Specific Overrides

#### Development Environment Customizations
```hcl
# In core/terraform.tfvars
service_tier = "small"
ec2_ssh_key  = null                    # No SSH access for security
enable_deletion_protection = false     # Allow easy cleanup

# Development-specific features
enable_eks_public_endpoint = true      # Easier access for developers
rds_backup_retention = 3               # Shorter retention for cost savings
```

#### Production Environment Recommendations
```hcl
# In production core/terraform.tfvars
service_tier = "medium"                # Higher performance
ec2_ssh_key  = "production-debug-key"  # Emergency access only
enable_deletion_protection = true      # Prevent accidental deletion

# Production-specific features
enable_eks_public_endpoint = false     # Private API endpoint
rds_backup_retention = 14              # Longer retention for compliance
enable_multi_az = true                 # High availability
```

### Resource-Specific Customizations

#### Custom EKS Node Groups
```yaml
# In service-tiers.yaml, add to desired tier:
node_groups:
  - name: "general-purpose"
    instance_types: ["t3.medium", "t3.large"]
    capacity_type: "ON_DEMAND"
    desired_size: 2
    max_size: 10
    min_size: 1
  - name: "spot-instances"
    instance_types: ["t3.medium", "t3.large", "m5.large"]
    capacity_type: "SPOT"
    desired_size: 1
    max_size: 20
    min_size: 0
    taints:
      - key: "spot-instance"
        value: "true"
        effect: "NoSchedule"
```

#### Custom RDS Parameters
```hcl
# Custom parameter group settings can be added to RDS module
custom_db_parameters = [
  {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pg_cron,pgaudit"
  },
  {
    name  = "max_connections"
    value = "500"
  },
  {
    name  = "work_mem"
    value = "16384"  # 16MB
  }
]
```

#### Custom Supabase Resources
```yaml
# In helm-charts/supabase-custom/values.yaml
postgrest:
  resources:
    requests:
      cpu: "200m"      # Increased from 100m
      memory: "512Mi"   # Increased from 256Mi
    limits:
      cpu: "1000m"     # Increased from 500m
      memory: "1Gi"    # Increased from 512Mi

# Custom HPA settings
autoscaling:
  postgrest:
    minReplicas: 3                     # Increased from 2
    maxReplicas: 15                    # Increased from 5
    targetCPUUtilizationPercentage: 60 # More aggressive scaling
```

## 📊 Monitoring Configuration

### CloudWatch Integration
```hcl
# Log groups and retention
log_groups = [
  {
    name              = "/aws/eks/supabase-development-eks/cluster"
    retention_in_days = 7
  },
  {
    name              = "/aws/vpc/flowlogs"
    retention_in_days = 3
  }
]

# CloudWatch alarms
alarms = [
  {
    name                = "EKS-HighCPU"
    metric_name         = "CPUUtilization"
    threshold           = 80
    comparison_operator = "GreaterThanThreshold"
  },
  {
    name                = "RDS-DatabaseConnections"
    metric_name         = "DatabaseConnections"
    threshold           = 80
    comparison_operator = "GreaterThanThreshold"
  }
]
```

### Prometheus Ready Configuration
```yaml
# In helm-charts/supabase-custom/values.yaml
serviceMonitor:
  enabled: false  # Set to true when Prometheus is installed
  namespace: monitoring
  interval: 30s
  scrapeTimeout: 10s
  labels:
    release: prometheus
```

## 🔄 Configuration Management Workflow

### Making Configuration Changes

1. **Plan Changes**
   ```bash
   # Always plan before applying
   cd environments/ireland/development/core
   terraform plan -out=config-change.tfplan
   ```

2. **Review Changes**
   ```bash
   # Review the planned changes
   terraform show config-change.tfplan
   ```

3. **Apply Changes**
   ```bash
   # Apply during maintenance window
   terraform apply config-change.tfplan
   ```

4. **Verify Changes**
   ```bash
   # Verify resources are healthy
   kubectl get pods -n supabase
   kubectl get nodes
   ```

### Configuration Backup
```bash
# Backup current configuration
mkdir -p backups/$(date +%Y-%m-%d)
cp -r environments/ backups/$(date +%Y-%m-%d)/
cp service-tiers.yaml backups/$(date +%Y-%m-%d)/

# Backup Terraform state
aws s3 cp s3://terraform-state-bucket/supabase/ backups/$(date +%Y-%m-%d)/state/ --recursive
```

## 🛠️ Troubleshooting Configuration Issues

### Common Configuration Problems

#### Service Tier Not Applied
```bash
# Check if service tier is properly referenced
grep -r "local.current_tier" modules/

# Verify service-tiers.yaml syntax
python -c "import yaml; yaml.safe_load(open('service-tiers.yaml'))"

# Check Terraform variables
terraform console
> local.current_tier
```

#### Secrets Not Syncing
```bash
# Check External Secrets Operator
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets

# Check SecretStore configuration
kubectl describe secretstore aws-secrets-manager -n supabase

# Verify IAM permissions for External Secrets
aws sts get-caller-identity
aws iam get-role --role-name supabase-development-external-secrets-role
```

#### HPA Not Scaling
```bash
# Check HPA status
kubectl describe hpa -n supabase

# Check metrics server
kubectl get deployment metrics-server -n kube-system

# Check pod resource requests (required for HPA)
kubectl describe pods -n supabase | grep -A 5 -B 5 "Requests:"
```

### Configuration Validation

```bash
# Validate Terraform configuration
terraform validate

# Check Helm chart syntax
helm lint helm-charts/supabase-custom/

# Validate Kubernetes manifests
kubectl --dry-run=client apply -f helm-charts/supabase-custom/templates/

# Test service tier configuration
python3 -c "
import yaml
with open('service-tiers.yaml') as f:
    tiers = yaml.safe_load(f)
    print('Available tiers:', list(tiers['tiers'].keys()))
    print('Small tier config:', tiers['tiers']['small'])
"
```

---

This configuration guide provides comprehensive coverage of all configurable aspects of the Supabase AWS infrastructure. For implementation details, see [DEPLOYMENT.md](DEPLOYMENT.md), and for architectural information, see [CURRENT_ARCHITECTURE.md](CURRENT_ARCHITECTURE.md).