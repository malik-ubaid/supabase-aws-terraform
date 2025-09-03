# Supabase on AWS Infrastructure

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Terraform-623CE4)](https://terraform.io)
[![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900)](https://aws.amazon.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5)](https://kubernetes.io)
[![Database](https://img.shields.io/badge/Database-PostgreSQL-336791)](https://postgresql.org)

Enterprise-grade Infrastructure as Code for deploying [Supabase](https://supabase.com/) on AWS using Terraform, EKS, and cloud-native services.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Account (eu-west-1)                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                      VPC                                │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │ │
│  │  │   AZ-1a     │  │   AZ-1b     │  │   AZ-1c     │    │ │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │    │ │
│  │  │ │ Public  │ │  │ │ Public  │ │  │ │ Public  │ │    │ │
│  │  │ │ Subnet  │ │  │ │ Subnet  │ │  │ │ Subnet  │ │    │ │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │    │ │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │    │ │
│  │  │ │   EKS   │ │  │ │   EKS   │ │  │ │   EKS   │ │    │ │
│  │  │ │ Private │ │  │ │ Private │ │  │ │ Private │ │    │ │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │    │ │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │    │ │
│  │  │ │   RDS   │ │  │ │   RDS   │ │  │ │   RDS   │ │    │ │
│  │  │ │ Private │ │  │ │ Private │ │  │ │ Private │ │    │ │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │    │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Managed AWS Services                       │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │ │
│  │  │   Secrets   │ │     S3      │ │     ALB     │      │ │
│  │  │   Manager   │ │   Storage   │ │   Ingress   │      │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘      │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🎛️ Service Tier System

This project uses a **centralized service tier system** controlled by a single configuration file (`service-tiers.yaml`) for cost control and easy scaling:

| Tier | Monthly Cost | Use Case | EKS Nodes | RDS Instance | Features |
|------|-------------|----------|-----------|--------------|----------|
| **minimal** | $50-80 | 🧪 Development/Testing | 1x t3.small (SPOT) | db.t3.micro | Single-AZ, minimal resources |
| **small** | $150-250 | 🏢 Small Production | 2x t3.medium | db.t3.small | HPA enabled, Multi-AZ optional |
| **medium** | $300-500 | 🚀 Standard Production | 2x t3.large | db.t3.medium | Multi-AZ, enhanced monitoring |
| **large** | $800-1200 | 📈 High Traffic | 3x m5.large+ | db.r6g.large | High performance, private endpoints |
| **xlarge** | $2000+ | 🏭 Enterprise Scale | 5x m5.xlarge+ | db.r6g.xlarge | Maximum scale, all features enabled |

### 🔧 Current Configuration (Small Tier)
- **EKS**: 2-4 t3.medium nodes with auto-scaling
- **RDS**: db.t3.small PostgreSQL 15.8
- **Storage**: S3 with versioning and access logging
- **Supabase**: HPA enabled (2-10 replicas per service)
- **Monitoring**: CloudWatch logs and metrics

### 💡 Quick Tier Selection

```bash
# For development/testing (recommended)
./scripts/validate-tier.sh minimal

# Change tier anytime
./scripts/change-tier.sh small development
```

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://terraform.io/downloads) >= 1.12
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [Helm](https://helm.sh/docs/intro/install/) >= 3.12
- AWS credentials configured with appropriate permissions

### One-Command Deployment

```bash
# Clone and deploy with minimal tier (cost-optimized for testing)
git clone <repository-url>
cd supabase-aws-infrastructure
./scripts/deploy.sh development eu-west-1
```

### Manual Deployment (Step-by-Step)

1. **Configure service tier**
   ```bash
   # Set tier in terraform.tfvars (minimal = lowest cost)
   echo 'service_tier = "minimal"' > environments/ireland/development/core/terraform.tfvars
   ```

2. **Deploy infrastructure**
   ```bash
   # Deploy networking
   cd environments/ireland/development/networking
   terraform init && terraform apply

   # Deploy core (EKS, RDS, S3, Secrets)
   cd ../core  
   terraform init && terraform apply

   # Configure kubectl
   aws eks update-kubeconfig --name supabase-development-eks --region eu-west-1

   # Deploy Supabase
   cd ../applications
   terraform init && terraform apply
   ```

3. **Verify deployment**
   ```bash
   ./scripts/smoke-test.sh development supabase
   ```

## 📁 Project Structure

```
supabase-aws-infrastructure/
├── service-tiers.yaml             # 🎛️ Centralized tier configurations
├── environments/                  # Environment-specific configurations
│   └── ireland/development/      # Ireland dev environment
│       ├── networking/           # VPC, subnets, routing
│       ├── core/                 # EKS, RDS, S3, Secrets
│       └── applications/         # Supabase deployment
├── modules/                      # Reusable Terraform modules
│   ├── networking/               # VPC and networking components
│   ├── iam/                     # Identity and Access Management
│   ├── eks/                     # EKS cluster and node groups
│   ├── rds/                     # PostgreSQL database
│   ├── s3/                      # Object storage
│   ├── secrets/                 # AWS Secrets Manager
│   └── supabase/                # Supabase Helm deployment
├── helm-charts/                 # Custom Helm charts
│   └── supabase-custom/         # Customized Supabase values
├── scripts/                     # Deployment and utility scripts
│   ├── deploy.sh               # One-command deployment
│   ├── destroy.sh              # Infrastructure cleanup
│   ├── validate-tier.sh        # Tier validation and info
│   ├── change-tier.sh          # Change service tiers
│   └── smoke-test.sh           # Deployment verification
├── SERVICE_TIERS.md            # Service tier documentation
├── IMPLEMENTATION_PLAN.md      # Detailed implementation plan
├── DEPLOYMENT.md               # Step-by-step deployment guide
└── README.md                   # This file
```

## 💰 Cost-Optimized for Testing

### Minimal Tier (Default)
The project defaults to the **`minimal`** tier for maximum cost savings during development and testing:

- **~$50-80/month** total infrastructure cost
- **SPOT instances** for 60-90% EC2 savings  
- **db.t3.micro** (free tier eligible)
- **Single-AZ** deployment (no Multi-AZ costs)
- **Minimal resources** allocated to all components

### Quick Cost Control

```bash
# Check current tier and costs
./scripts/validate-tier.sh minimal

# Scale up for staging/production
./scripts/change-tier.sh small development

# Scale back down after testing
./scripts/change-tier.sh minimal development
```

**💡 Recommendation**: Always start with `minimal` tier and scale up only when performance metrics justify the cost increase.

## 🏗️ Infrastructure Components

### Core Infrastructure

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| **VPC** | Network isolation | Multi-AZ with public/private subnets |
| **EKS** | Kubernetes platform | Managed cluster with auto-scaling |
| **RDS** | PostgreSQL database | Multi-AZ with automated backups |
| **S3** | Object storage | Encrypted bucket for Supabase files |
| **Secrets Manager** | Secrets storage | Centralized secret management |
| **ALB** | Load balancing | Application Load Balancer with SSL |

### Supabase Services (Deployed via Helm)

| Service | Description | Replicas | Ports | Auto-scaling |
|---------|-------------|----------|-------|---------------|
| **Kong Gateway** | API gateway and proxy | 2 | 8000 | HPA (2-10) |
| **PostgREST** | Auto-generated REST API | 2 | 3000 | HPA (2-10) |
| **Realtime** | WebSocket subscriptions | 2 | 4000 | HPA (2-5) |
| **Auth (GoTrue)** | User authentication | 2 | 9999 | HPA (2-5) |
| **Storage API** | File upload/management | 2 | 5000 | HPA (2-5) |
| **Dashboard** | Admin interface | 1 | 3000 | Fixed |

## 🔒 Security Features

- ✅ **Network Isolation**: Private subnets for EKS and RDS workloads
- ✅ **Secrets Management**: AWS Secrets Manager + External Secrets Operator
- ✅ **IAM Least Privilege**: Service Account roles with IRSA integration
- ✅ **Encryption**: KMS keys for RDS/S3, encrypted EBS volumes
- ✅ **Security Groups**: Port-specific rules (5432 for RDS, 443 for ALB)
- ✅ **VPC Endpoints**: Private connectivity to S3 and Secrets Manager
- ✅ **HTTPS Only**: ALB with SSL termination
- ✅ **Pod Security**: Non-root containers, read-only file systems
- ✅ **Network Policies**: Kubernetes-level traffic control

## 📊 Monitoring & Observability

### Built-in Monitoring
- **CloudWatch Logs**: EKS cluster and application logs
- **CloudWatch Metrics**: Infrastructure and application metrics
- **CloudWatch Alarms**: Critical threshold alerting
- **VPC Flow Logs**: Network traffic analysis

### Ready for Advanced Monitoring
- **Prometheus**: Metrics collection (Helm chart ready)
- **Grafana**: Visualization dashboards (Helm chart ready)
- **Jaeger**: Distributed tracing support
- **Fluent Bit**: Log forwarding and processing

## 🔧 Configuration

### Environment Variables
Key configuration options in `terraform.tfvars`:

```hcl
# Service Tier Control (drives all other configurations)
service_tier = "small"  # Options: minimal, small, medium, large, xlarge

# Basic Configuration
region       = "eu-west-1"
environment  = "development"
project_name = "supabase"

# Optional: SSH access (null for production security)
ec2_ssh_key = null

# All other settings are automatically configured based on service_tier
# See service-tiers.yaml for complete tier specifications
```

### Supabase Configuration
Configure Supabase features in Helm values:

```yaml
supabase:
  features:
    auth: true
    storage: true
    realtime: true
    dashboard: true
  
  scaling:
    postgrest:
      minReplicas: 2
      maxReplicas: 10
    realtime:
      minReplicas: 2
      maxReplicas: 5
```

## 🔄 Operational Procedures

### Scaling Operations

**Scale EKS Nodes:**
```bash
# Update node group desired capacity
aws eks update-nodegroup-config \
  --cluster-name supabase-dev-eks \
  --nodegroup-name supabase-nodes \
  --scaling-config desiredSize=5,maxSize=10,minSize=2
```

**Scale Application Pods:**
```bash
# Scale PostgREST replicas
kubectl scale deployment supabase-postgrest -n supabase --replicas=5
```

### Backup Operations

**Database Backup:**
```bash
# Create manual RDS snapshot
aws rds create-db-snapshot \
  --db-snapshot-identifier supabase-manual-$(date +%Y%m%d) \
  --db-instance-identifier supabase-postgresql
```

**Configuration Backup:**
```bash
# Export Kubernetes secrets and configs
kubectl get secrets,configmaps -n supabase -o yaml > supabase-config-backup.yaml
```

### Maintenance Windows

- **Database Maintenance**: Sunday 04:00-05:00 UTC
- **Node Updates**: Automated during off-peak hours
- **Application Updates**: Rolling deployments during business hours

## 🚨 Troubleshooting

### Common Issues

**EKS Cluster Access:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name supabase-dev-eks --region eu-west-1

# Check cluster status
kubectl get nodes
kubectl cluster-info
```

**Database Connectivity:**
```bash
# Test database connection from pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql postgresql://username:password@rds-endpoint:5432/postgres
```

**Application Health:**
```bash
# Check Supabase services
kubectl get pods -n supabase
kubectl logs -n supabase -l app=supabase-postgrest
kubectl describe ingress supabase-ingress -n supabase
```

### Log Locations

- **EKS Control Plane**: CloudWatch Logs `/aws/eks/supabase-dev-eks/cluster`
- **Application Logs**: `kubectl logs -n supabase <pod-name>`
- **VPC Flow Logs**: CloudWatch Logs `/aws/vpc/flowlogs`

## 💰 Cost Optimization

### Included Optimizations

- **Spot Instances**: Mixed instance types for node groups
- **S3 Lifecycle**: Automatic transition to IA/Glacier storage classes
- **RDS Reserved Instances**: Option for production workloads
- **ALB Target Groups**: Efficient traffic routing

### Estimated Monthly Costs (Development)

| Service | Instance Type | Estimated Cost |
|---------|---------------|----------------|
| EKS Cluster | Control Plane | $73 |
| EC2 Nodes | 2x t3.large | $120 |
| RDS PostgreSQL | db.t3.medium | $85 |
| S3 Storage | 100GB | $3 |
| ALB | Application LB | $18 |
| **Total** | | **~$300/month** |

*Costs may vary based on usage patterns and AWS region*

## 🔮 Roadmap

### Phase 1 - Foundation ✅
- [x] Infrastructure as Code with Terraform
- [x] EKS cluster with managed node groups
- [x] RDS PostgreSQL with Multi-AZ
- [x] S3 storage integration
- [x] Secrets management
- [x] Basic monitoring

### Phase 2 - Production Readiness 🚧
- [ ] Multi-region deployment
- [ ] Advanced monitoring with Prometheus/Grafana
- [ ] Automated backup strategies
- [ ] Blue-green deployment pipeline
- [ ] Custom domain and SSL automation

### Phase 3 - Advanced Features 📋
- [ ] GitOps with ArgoCD
- [ ] Service mesh integration
- [ ] Advanced security scanning
- [ ] Cost optimization automation
- [ ] Compliance reporting

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the [Implementation Plan](IMPLEMENTATION_PLAN.md) for detailed guidance
- **Issues**: Report bugs and feature requests via GitHub Issues
- **Discussions**: Join community discussions for questions and ideas

---

**Built with ❤️ for the Supabase and AWS community**