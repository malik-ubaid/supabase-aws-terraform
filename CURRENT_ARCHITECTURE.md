# Supabase AWS Infrastructure - Current Architecture

## 🏗️ Architecture Overview

This document describes the current state of the implemented Supabase on AWS infrastructure, deployed using Terraform and Kubernetes.

## 📊 Architecture Diagram

![Architecture Diagram](../supabase-architecture.drawio)

The complete architecture diagram is available as a draw.io file showing all implemented components, their relationships, and data flows.

## 🎯 Current Implementation Status

### ✅ FULLY IMPLEMENTED
- **Infrastructure as Code**: Modular Terraform with service-tier configuration
- **Container Platform**: Amazon EKS v1.30 with auto-scaling node groups
- **Database**: RDS PostgreSQL 15.8 with encryption and automated backups
- **Storage**: S3 bucket with versioning, encryption, and lifecycle policies
- **Secrets**: AWS Secrets Manager with External Secrets Operator integration
- **Security**: VPC isolation, IRSA, KMS encryption, pod security policies
- **Auto-scaling**: HPA (2-10 replicas) and Cluster Autoscaler
- **Service Tiers**: Configurable infrastructure sizing via YAML configuration
- **Application Deployment**: Custom Helm chart with complete AWS integration

## 🏛️ Infrastructure Components

### AWS Region: eu-west-1
- **Availability Zones**: 3 AZs (eu-west-1a, eu-west-1b, eu-west-1c)
- **VPC CIDR**: 10.0.0.0/16

### Network Architecture
```
VPC (10.0.0.0/16)
├── Public Subnets (3 AZs)
│   ├── 10.0.1.0/24 (ALB, NAT Gateway)
│   ├── 10.0.2.0/24 (ALB, NAT Gateway)
│   └── 10.0.3.0/24 (ALB, NAT Gateway)
├── EKS Private Subnets (3 AZs)
│   ├── 10.0.10.0/24 (Worker nodes)
│   ├── 10.0.11.0/24 (Worker nodes)
│   └── 10.0.12.0/24 (Worker nodes)
└── RDS Private Subnets (3 AZs)
    ├── 10.0.20.0/24 (Database)
    ├── 10.0.21.0/24 (Database)
    └── 10.0.22.0/24 (Database)
```

### Core AWS Services

#### Amazon EKS Cluster
- **Name**: supabase-development-eks
- **Version**: 1.30
- **Endpoint**: Private API server with controlled public access
- **Node Groups**: 
  - General purpose: t3.medium instances (1-2 nodes, on-demand)
  - Auto-scaling: Cluster Autoscaler deployed
  - Storage: EBS CSI driver with gp3 volumes

#### Amazon RDS PostgreSQL
- **Instance**: db.t3.small (configurable via service tiers)
- **Engine**: PostgreSQL 15.8
- **Storage**: 50GB with auto-scaling enabled
- **Backup**: 3-day retention with automated backups
- **Security**: Encryption at rest with KMS, VPC isolation
- **Parameters**: Optimized for Supabase (shared_preload_libraries, max_connections)

#### Amazon S3 Storage
- **Bucket**: Supabase file storage backend
- **Features**: Versioning, encryption (KMS), access logging
- **Access**: IAM role-based with service account integration
- **Lifecycle**: Automatic transition to IA storage classes

#### AWS Secrets Manager
- **Database Credentials**: Auto-generated with rotation capability
- **Supabase Configuration**: JWT secrets, API keys
- **Integration**: External Secrets Operator for Kubernetes secret sync

#### Network Security
- **Security Groups**: Port-specific access (5432 for RDS, 443 for ALB)
- **VPC Endpoints**: Private access to S3 and Secrets Manager
- **Network Policies**: Kubernetes-level traffic control

## 🎛️ Service Tier Configuration

### Current Tier: Small ($150-250/month)
Controlled by `service-tiers.yaml` configuration:

```yaml
small:
  description: "Small production setup for low-traffic applications"
  monthly_cost_estimate: "$150-250"
  use_cases: ["small production", "staging", "demos"]
  
  eks:
    cluster_version: "1.30"
    node_groups:
      - name: "small-general"
        instance_types: ["t3.medium"]
        capacity_type: "ON_DEMAND"
        desired_size: 2
        max_size: 4
  
  rds:
    instance_class: "db.t3.small"
    allocated_storage: 50
    engine_version: "15.8"
    multi_az: false
    backup_retention_period: 3
  
  supabase:
    enable_hpa: true
    resources:
      kong: { cpu: "100m", memory: "256Mi" }
      postgrest: { cpu: "100m", memory: "256Mi" }
    hpa:
      postgrest: { min: 2, max: 5, cpu_target: 70 }
```

## 🐳 Kubernetes Workloads

### Namespace: supabase
All Supabase services run in a dedicated namespace with proper RBAC and network policies.

### Deployed Services

| Service | Image | Replicas | Resources | Auto-scaling |
|---------|-------|----------|-----------|--------------|
| **Kong Gateway** | kong:3.4 | 2 | 100m CPU, 256Mi RAM | HPA (2-5) |
| **PostgREST** | postgrest/postgrest:v12.0.2 | 2 | 100m CPU, 256Mi RAM | HPA (2-5) |
| **Realtime** | supabase/realtime:v2.25.50 | 2 | 100m CPU, 256Mi RAM | HPA (2-5) |
| **Auth (GoTrue)** | supabase/gotrue:v2.143.0 | 2 | 100m CPU, 256Mi RAM | HPA (2-5) |
| **Storage API** | supabase/storage-api:v0.46.4 | 2 | 100m CPU, 256Mi RAM | HPA (2-5) |
| **Dashboard** | supabase/studio:20240326-5e5586d | 1 | 100m CPU, 256Mi RAM | Fixed |

### Service Ports
- **Kong**: 8000 (API Gateway entry point)
- **PostgREST**: 3000 (REST API)
- **Realtime**: 4000 (WebSocket subscriptions)
- **Auth**: 9999 (Authentication)
- **Storage**: 5000 (File management)
- **Dashboard**: 3000 (Admin interface)

### External Access
- **Application Load Balancer**: Internet-facing ALB with SSL termination
- **Ingress**: Kubernetes ingress controller routing traffic to Kong
- **DNS**: Configurable custom domain support

## 🔒 Security Implementation

### Network Security
- **Private Subnets**: All workloads run in private subnets
- **Security Groups**: Restrictive rules (RDS only accessible from EKS nodes)
- **VPC Endpoints**: Private AWS service access (S3, Secrets Manager)
- **Network Policies**: Kubernetes-level traffic segmentation

### Identity and Access Management
- **IRSA**: IAM Roles for Service Accounts integration
- **Service Accounts**: Dedicated roles for External Secrets, Storage API
- **Least Privilege**: Minimal required permissions for each component

### Encryption
- **At Rest**: KMS keys for RDS, S3, and EBS volumes
- **In Transit**: TLS for all communications
- **Secrets**: Encrypted in Secrets Manager with automatic rotation

### Pod Security
- **Security Contexts**: Non-root containers, read-only root filesystems
- **Resource Limits**: CPU and memory limits enforced
- **Image Security**: Official Supabase and verified images only

## 📈 Monitoring and Observability

### Built-in Monitoring
- **CloudWatch Logs**: EKS cluster logs, application logs
- **CloudWatch Metrics**: Infrastructure and application metrics
- **VPC Flow Logs**: Network traffic analysis
- **RDS Enhanced Monitoring**: Database performance metrics

### Application Monitoring
- **Health Checks**: Kubernetes liveness and readiness probes
- **Metrics Collection**: Ready for Prometheus integration
- **Log Aggregation**: Centralized logging with structured formats

## 🔄 Operational Procedures

### Deployment Process
1. **Infrastructure**: Terraform modules deployed in layers (networking → core → applications)
2. **Applications**: Helm-based deployment with External Secrets integration
3. **Secrets**: Automatic sync from AWS Secrets Manager to Kubernetes secrets

### Scaling Operations
- **Horizontal Pod Autoscaling**: Automatic pod scaling based on CPU/memory
- **Cluster Autoscaling**: Automatic node scaling based on resource demands
- **Manual Scaling**: Configurable via service tier changes

### Backup and Recovery
- **Database**: Automated RDS backups with 3-day retention
- **Configuration**: Terraform state in S3 with versioning
- **Application State**: Stateless design with external storage

## 💰 Cost Optimization

### Current Optimizations
- **Service Tiers**: Right-sized resources based on workload requirements
- **Spot Instances**: Optional spot node groups for cost savings
- **Storage Lifecycle**: Automatic S3 object transitions
- **Resource Limits**: Prevent resource waste with enforced limits

### Cost Monitoring
- **Tagging Strategy**: Consistent tagging for cost allocation
- **Service Tier Impact**: Clear cost implications for tier changes
- **Resource Utilization**: Monitoring for optimization opportunities

## 🔮 Future Enhancements

### Ready for Implementation
- **Multi-Region**: Architecture supports multi-region deployment
- **Advanced Monitoring**: Prometheus/Grafana stack ready for deployment
- **GitOps**: ArgoCD integration for declarative deployments
- **Custom Domains**: Route53 integration for automated DNS management

### Infrastructure Improvements
- **Service Mesh**: Istio/Linkerd for advanced traffic management
- **Blue-Green Deployments**: Zero-downtime deployment strategies
- **Disaster Recovery**: Cross-region backup and failover procedures

## 📋 Configuration Files

### Key Configuration Files
- `service-tiers.yaml`: Central service tier configuration
- `environments/ireland/development/core/terraform.tfvars`: Environment-specific settings
- `helm-charts/supabase-custom/values.yaml`: Supabase application configuration
- `modules/*/`: Reusable Terraform modules for each component

### Environment Variables
Current development environment configured with:
- **Region**: eu-west-1
- **Environment**: development
- **Project**: supabase
- **Service Tier**: small

## 🧪 Testing and Validation

### Deployment Validation
- **Infrastructure Tests**: Terraform plan validation
- **Security Scanning**: Resource configuration security checks
- **Health Checks**: Application endpoint validation
- **Integration Tests**: End-to-end API functionality

### Monitoring Validation
- **Metrics Collection**: CloudWatch metrics flowing correctly
- **Log Aggregation**: Application and infrastructure logs available
- **Alert Configuration**: Basic alerting for critical components

---

This architecture represents a production-ready, secure, and scalable Supabase deployment on AWS, with comprehensive automation, monitoring, and cost optimization features.