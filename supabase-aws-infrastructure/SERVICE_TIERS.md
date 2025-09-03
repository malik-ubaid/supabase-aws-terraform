# Service Tier Configuration Guide

This document explains how to use the centralized service tier system to control infrastructure costs and sizing.

## 🎛️ Overview

The Supabase infrastructure uses a **centralized service tier system** that allows you to control all infrastructure sizing and costs through a single variable. This ensures consistent resource allocation and makes it easy to scale up or down based on your needs.

## 📊 Available Service Tiers

### `minimal` - Development & Testing 💡
- **Monthly Cost**: $50-80
- **Use Cases**: Development, testing, proof-of-concept
- **EKS**: 1x t3.small node (SPOT)
- **RDS**: db.t3.micro, 20GB, no Multi-AZ
- **Resources**: Minimal CPU/memory allocation
- **Features**: No HPA, no monitoring, simplified setup

```yaml
# Example minimal tier configuration
eks:
  node_groups:
    - name: "minimal-nodes"
      instance_types: ["t3.small", "t3.medium"]
      capacity_type: "SPOT"
      desired_size: 1
      max_size: 2

rds:
  instance_class: "db.t3.micro"
  allocated_storage: 20
  multi_az: false
  backup_retention_period: 1
```

### `small` - Small Production 🏢
- **Monthly Cost**: $150-250
- **Use Cases**: Small production, staging, demos
- **EKS**: 2x t3.medium nodes + spot scaling
- **RDS**: db.t3.small, 50GB, single AZ
- **Resources**: Basic CPU/memory with HPA
- **Features**: HPA enabled, basic monitoring

### `medium` - Standard Production 🚀
- **Monthly Cost**: $300-500
- **Use Cases**: Medium production, business applications
- **EKS**: 2x t3.large nodes + spot scaling
- **RDS**: db.t3.medium, 100GB, Multi-AZ
- **Resources**: Standard allocation with full HPA
- **Features**: Full monitoring, enhanced security

### `large` - High Traffic Production 📈
- **Monthly Cost**: $800-1200
- **Use Cases**: Large production, enterprise applications
- **EKS**: 3x m5.large+ nodes with extensive scaling
- **RDS**: db.r6g.large, 500GB, Multi-AZ
- **Resources**: High performance allocation
- **Features**: Advanced monitoring, private endpoints

### `xlarge` - Enterprise Scale 🏭
- **Monthly Cost**: $2000+
- **Use Cases**: Enterprise production, high-scale applications
- **EKS**: 5x m5.xlarge+ nodes with massive scaling
- **RDS**: db.r6g.xlarge, 1TB+, Multi-AZ
- **Resources**: Maximum performance allocation
- **Features**: Enterprise-grade monitoring and security

## 🔧 How to Use Service Tiers

### Setting a Service Tier

**Option 1: Update terraform.tfvars**
```bash
# Edit core configuration
vim environments/ireland/development/core/terraform.tfvars

# Change this line:
service_tier = "minimal"  # Change to desired tier
```

**Option 2: Use the change-tier script**
```bash
# Interactive tier change
./scripts/change-tier.sh small development

# Validate tier configuration
./scripts/validate-tier.sh small
```

### Deploying with a Specific Tier

```bash
# Deploy with minimal tier (default)
./scripts/deploy.sh development eu-west-1

# Or deploy manually
cd environments/ireland/development/core
terraform apply -var="service_tier=minimal"
```

## 💰 Cost Optimization Strategies

### For Development/Testing (Recommended: `minimal`)

```yaml
# Minimal tier optimizations:
- Uses SPOT instances (60-90% cost savings)
- Single node setup
- db.t3.micro (free tier eligible)
- No Multi-AZ deployment
- Reduced backup retention
- No enhanced monitoring
- Simplified networking (public EKS endpoint)
```

**Estimated Monthly Cost: $50-80**

### Cost Breakdown (Minimal Tier):
- **EKS Control Plane**: $73/month
- **EC2 Node (t3.small SPOT)**: ~$5/month  
- **RDS (db.t3.micro)**: ~$12/month (or free with free tier)
- **S3 Storage**: ~$3/month (for 100GB)
- **ALB**: ~$18/month
- **Secrets Manager**: ~$2/month

### For Production (Recommended: `small` or `medium`)

Start with `small` tier and monitor:
- Resource utilization
- Response times
- Error rates
- Cost trends

Scale up to `medium` or `large` only when metrics justify the increase.

## 🚀 Quick Tier Changes

### Scaling Up (e.g., minimal → small)

```bash
# 1. Change tier
./scripts/change-tier.sh small development

# 2. Plan changes
cd environments/ireland/development/core
terraform plan

# 3. Apply during maintenance window
terraform apply

# 4. Update applications
cd ../applications
terraform plan && terraform apply
```

### Scaling Down (e.g., medium → small)

```bash
# ⚠️ CAUTION: May cause service interruption

# 1. Drain workloads (if needed)
kubectl drain nodes --selector="node-type=on-demand" --ignore-daemonsets

# 2. Change tier
./scripts/change-tier.sh small development

# 3. Apply changes
cd environments/ireland/development/core
terraform apply
```

## 📋 Tier Comparison Matrix

| Feature | minimal | small | medium | large | xlarge |
|---------|---------|-------|--------|-------|--------|
| **EKS Nodes** | 1-2 | 2-4 | 2-8 | 5-20 | 5-50 |
| **Instance Types** | t3.small | t3.medium | t3.large | m5.large+ | m5.xlarge+ |
| **RDS Instance** | t3.micro | t3.small | t3.medium | r6g.large | r6g.xlarge |
| **Multi-AZ RDS** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **HPA Enabled** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Performance Insights** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Enhanced Monitoring** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Private Endpoints** | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Backup Retention** | 1 day | 3 days | 7 days | 14 days | 30 days |

## 🔍 Monitoring Your Tier

### Resource Utilization

```bash
# Check node utilization
kubectl top nodes

# Check pod resource usage
kubectl top pods -n supabase

# Check HPA status
kubectl get hpa -n supabase
```

### Cost Monitoring

```bash
# AWS Cost Explorer (by service tier tag)
aws ce get-dimension-values \
  --dimension SERVICE \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --filter '{"Tags":{"Key":"ServiceTier","Values":["minimal"]}}'

# Resource-specific costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

### Performance Monitoring

```bash
# Database performance
aws rds describe-db-instances --db-instance-identifier supabase-development-postgresql

# Application metrics
kubectl get pods -n supabase -o wide
```

## ⚠️ Important Considerations

### Tier Change Impact

**Scaling Up (minimal → larger tiers):**
- ✅ Generally safe operation
- ✅ No data loss expected
- ⏳ Brief service interruption during node replacement

**Scaling Down (larger → smaller tiers):**
- ⚠️ May cause resource constraints
- ⚠️ Could impact performance
- 🔍 Monitor applications closely after change

### Production Recommendations

1. **Start Small**: Begin with `small` tier for new production workloads
2. **Monitor First**: Collect metrics before scaling decisions
3. **Gradual Changes**: Scale one tier at a time
4. **Maintenance Windows**: Plan tier changes during low-traffic periods
5. **Backup First**: Ensure backups are current before major changes

### Cost Alerts

Set up CloudWatch billing alerts:

```bash
# Create a billing alarm for $100/month
aws cloudwatch put-metric-alarm \
  --alarm-name "Supabase-Cost-Alert" \
  --alarm-description "Alert when Supabase costs exceed $100" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold
```

## 🛠️ Customization Options

### Override Specific Resources

While service tiers provide good defaults, you can override specific settings:

```hcl
# In terraform.tfvars
service_tier = "minimal"

# Override specific settings
override_rds_instance_class = "db.t3.small"  # Upgrade just the database
override_node_instance_types = ["t3.medium"] # Upgrade just the nodes
```

### Environment-Specific Adjustments

```hcl
# Development: minimal tier
service_tier = "minimal"

# Staging: small tier  
service_tier = "small"

# Production: medium tier with overrides
service_tier = "medium"
override_cluster_version = "1.31"
```

## 📈 Scaling Guidelines

### When to Scale Up

Scale up when you observe:
- CPU utilization consistently > 70%
- Memory utilization consistently > 80%
- Database connections near maximum
- API response times > 500ms
- Frequent pod evictions

### When to Scale Down

Scale down when you observe:
- CPU utilization consistently < 30%
- Memory utilization consistently < 50%
- Over-provisioned resources for 30+ days
- Budget constraints require optimization

### Automatic Scaling

The tier system includes automatic scaling:
- **HPA**: Automatically scales pods based on CPU/memory
- **Cluster Autoscaler**: Automatically scales nodes based on pod demand
- **RDS Auto Scaling**: Automatically increases storage when needed

## 🎯 Best Practices

1. **Development**: Always use `minimal` tier to reduce costs
2. **Testing**: Use `minimal` or `small` for integration testing
3. **Staging**: Use same tier as production for accurate testing
4. **Production**: Start with `small`, scale based on actual usage
5. **Monitoring**: Set up alerts before scaling to larger tiers
6. **Documentation**: Document tier decisions and scaling triggers

---

For questions about service tiers or cost optimization, refer to the [Implementation Plan](IMPLEMENTATION_PLAN.md) or check the [Deployment Guide](DEPLOYMENT.md).