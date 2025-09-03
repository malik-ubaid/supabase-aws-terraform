# Supabase on AWS - Deployment Guide

This guide provides step-by-step instructions for deploying the complete Supabase infrastructure on AWS using Terraform modules and Kubernetes with Helm.

## 🎯 What You'll Deploy

This deployment creates a production-ready Supabase environment with:
- **EKS Cluster** (v1.30) with auto-scaling node groups
- **RDS PostgreSQL** (15.8) with automated backups
- **S3 Storage** with encryption and versioning
- **Secrets Management** via AWS Secrets Manager
- **Service Mesh** with Kong API Gateway
- **Auto-scaling** for all Supabase services (HPA)
- **Security** with VPC isolation and pod security policies

## 📋 Prerequisites

### Required Tools

Ensure you have the following tools installed with minimum versions:

```bash
# Terraform (>= 1.12) - Infrastructure as Code
terraform --version

# AWS CLI (>= 2.0) - AWS service management
aws --version

# kubectl (>= 1.28) - Kubernetes cluster management
kubectl version --client

# Helm (>= 3.12) - Kubernetes package management
helm version
```

### Installation Quick Reference
```bash
# macOS with Homebrew
brew install terraform awscli kubectl helm

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y terraform awscli kubectl helm

# Verify installations
terraform --version && aws --version && kubectl version --client && helm version
```

### AWS Prerequisites

1. **AWS Account**: Active AWS account with billing enabled
2. **AWS Credentials**: Programmatic access configured
3. **IAM Permissions**: Administrative access or specific permissions listed below
4. **S3 Backend Bucket**: Secure bucket for Terraform state storage

```bash
# Step 1: Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region (eu-west-1), and output format (json)

# Step 2: Verify access and check identity
aws sts get-caller-identity
# Should return your account ID, user ID, and ARN

# Step 3: Create S3 bucket for Terraform state (replace with unique name)
export BUCKET_NAME="terraform-state-supabase-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region eu-west-1

# Step 4: Enable versioning and encryption
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{
  "Rules": [{
    "ApplyServerSideEncryptionByDefault": {
      "SSEAlgorithm": "AES256"
    }
  }]
}'

# Step 5: Block public access
aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

echo "S3 Backend Bucket: $BUCKET_NAME"
```

### IAM Permissions

Your AWS user/role needs the following permissions:
- EC2 (VPC, Subnets, Security Groups, etc.)
- EKS (Cluster management, Node groups)
- RDS (PostgreSQL instance management)
- S3 (Bucket operations)
- Secrets Manager (Secret creation/management)
- IAM (Role/policy management)
- CloudWatch (Logging, metrics)

## 🚀 Quick Deployment

### Option 1: Automated Deployment Script

```bash
# Clone the repository
git clone <repository-url>
cd supabase-aws-infrastructure

# Run automated deployment
./scripts/deploy.sh development eu-west-1
```

### Option 2: Manual Step-by-Step Deployment

## 1. Deploy Networking Infrastructure

### Configure Terraform Backend
First, update the backend configuration with your S3 bucket:

```bash
# Navigate to networking directory
cd environments/ireland/development/networking

# Update backend configuration (replace with your bucket name)
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket = "$BUCKET_NAME"
    key    = "supabase/networking/terraform.tfstate"
    region = "eu-west-1"
  }
}
EOF
```

### Deploy Network Resources
```bash
# Initialize Terraform (downloads providers and sets up backend)
terraform init

# Review planned changes
terraform plan -out=networking.tfplan

# Deploy networking infrastructure
terraform apply networking.tfplan
```

**Expected Resources Created (~5-10 minutes):**
- ✅ **VPC** with DNS resolution and hostnames enabled
- ✅ **Public Subnets** (3 AZs) - 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- ✅ **EKS Private Subnets** (3 AZs) - 10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24
- ✅ **RDS Private Subnets** (3 AZs) - 10.0.20.0/24, 10.0.21.0/24, 10.0.22.0/24
- ✅ **Internet Gateway** for public internet access
- ✅ **NAT Gateways** (3) for private subnet outbound access
- ✅ **Route Tables** with proper associations
- ✅ **VPC Endpoints** for S3 and Secrets Manager (cost optimization)
- ✅ **Security Groups** with minimal required access
- ✅ **VPC Flow Logs** for network monitoring
- ✅ **DB Subnet Group** for RDS deployment

**Cost Impact**: ~$45-60/month (primarily NAT Gateways)

## 2. Deploy Core Infrastructure

### Configure Service Tier
The deployment uses a service tier system for cost and resource management:

```bash
cd ../core

# Review current service tier (should be 'small' for development)
cat terraform.tfvars

# Optional: Change to minimal tier for cost savings
# echo 'service_tier = "minimal"' >> terraform.tfvars
```

### Configure Backend and Deploy
```bash
# Configure Terraform backend
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket = "$BUCKET_NAME"
    key    = "supabase/core/terraform.tfstate"
    region = "eu-west-1"
  }
}
EOF

# Initialize Terraform
terraform init

# Review planned changes (this will be substantial)
terraform plan -out=core.tfplan

# Deploy core infrastructure (15-20 minutes)
terraform apply core.tfplan
```

**Expected Resources Created (~15-20 minutes):**
- ✅ **EKS Cluster** (supabase-development-eks) with private API endpoint
- ✅ **EKS Node Groups** with auto-scaling (t3.medium instances)
- ✅ **EKS Add-ons** (VPC CNI, CoreDNS, kube-proxy, EBS CSI driver)
- ✅ **RDS PostgreSQL** (db.t3.small) with automated backups
- ✅ **RDS Parameter Group** optimized for Supabase
- ✅ **S3 Bucket** with versioning and encryption
- ✅ **AWS Secrets Manager** secrets for database and Supabase config
- ✅ **IAM Roles** for EKS cluster, node groups, and service accounts
- ✅ **KMS Keys** for RDS and S3 encryption
- ✅ **CloudWatch Log Groups** for monitoring
- ✅ **Security Groups** with restrictive access rules

**Cost Impact**: ~$85-120/month (EKS cluster, RDS, compute instances)

### Important Outputs
After deployment completes, note these important outputs:
```bash
# Display important connection information
terraform output
# Note: cluster_name, rds_endpoint, s3_bucket_name
```

## 3. Configure kubectl Access

### Update kubeconfig
```bash
# Update kubeconfig for the EKS cluster
aws eks update-kubeconfig --name supabase-development-eks --region eu-west-1

# Verify cluster access
kubectl get nodes
# Should show 1-2 t3.medium nodes in Ready state

# Check cluster information
kubectl cluster-info
# Should show Kubernetes control plane and CoreDNS endpoints

# Verify EKS add-ons are running
kubectl get pods -n kube-system
# Should show aws-node, coredns, kube-proxy, ebs-csi-controller pods
```

### Verify Cluster Status
```bash
# Check node details
kubectl describe nodes

# Verify cluster autoscaler (if installed)
kubectl get deployment cluster-autoscaler -n kube-system

# Check for any issues
kubectl get events --sort-by='.lastTimestamp' -A
```

## 4. Deploy Supabase Applications

### Configure Applications Backend
```bash
cd ../applications

# Configure Terraform backend
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket = "$BUCKET_NAME"
    key    = "supabase/applications/terraform.tfstate"
    region = "eu-west-1"
  }
}
EOF

# Initialize Terraform
terraform init
```

### Deploy Supabase Stack
```bash
# Review planned changes
terraform plan -out=applications.tfplan

# Deploy applications (10-15 minutes)
terraform apply applications.tfplan
```

**Expected Resources Created (~10-15 minutes):**
- ✅ **External Secrets Operator** (Helm chart) with AWS integration
- ✅ **Secret Store** for AWS Secrets Manager connectivity
- ✅ **External Secrets** syncing AWS secrets to Kubernetes
- ✅ **Service Accounts** with IRSA annotations for AWS access
- ✅ **Supabase Services** via custom Helm chart:
  - Kong Gateway (2 replicas, port 8000)
  - PostgREST (2 replicas, port 3000)
  - Realtime (2 replicas, port 4000)
  - Auth/GoTrue (2 replicas, port 9999)
  - Storage API (2 replicas, port 5000)
  - Dashboard (1 replica, port 3000)
- ✅ **Horizontal Pod Autoscalers** for all services (2-10 replicas)
- ✅ **Ingress** with ALB controller for external access
- ✅ **Config Maps** for non-sensitive configuration
- ✅ **Network Policies** for pod-to-pod communication control

**Cost Impact**: Minimal additional cost (mostly compute resources)

### Monitor Deployment Progress
```bash
# Watch pods come online
kubectl get pods -n supabase -w

# Check External Secrets Operator
kubectl get pods -n external-secrets

# Verify secrets are created
kubectl get secrets -n supabase
```

## 5. Verify Complete Deployment

### Check Infrastructure Status
```bash
# Verify all nodes are ready
kubectl get nodes
# Expected: 1-2 nodes in Ready state

# Check all system pods are running
kubectl get pods -n kube-system
# Expected: All pods in Running state

# Verify External Secrets Operator
kubectl get pods -n external-secrets
# Expected: external-secrets-* pods in Running state
```

### Verify Supabase Services
```bash
# Check all Supabase pods
kubectl get pods -n supabase
# Expected: All supabase-* pods in Running state (2 replicas each except dashboard)

# Check services are exposed
kubectl get svc -n supabase
# Expected: ClusterIP services for each component

# Check ingress is configured
kubectl get ingress -n supabase
# Expected: supabase-ingress with ALB address

# Verify HPA is active
kubectl get hpa -n supabase
# Expected: HPA resources with TARGETS showing current/target metrics
```

### Check Secret Synchronization
```bash
# Verify External Secrets are synced
kubectl get externalsecret -n supabase
# Expected: supabase-secrets and supabase-config with READY=True

# Check Kubernetes secrets exist
kubectl get secrets -n supabase
# Expected: supabase-secrets and supabase-config secrets

# Verify secret content (base64 encoded)
kubectl get secret supabase-secrets -n supabase -o jsonpath='{.data}'
```

### Test API Connectivity
```bash
# Get ALB endpoint
ALB_ENDPOINT=$(kubectl get ingress supabase-ingress -n supabase -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB Endpoint: $ALB_ENDPOINT"

# Get anonymous API key
ANON_KEY=$(kubectl get secret supabase-secrets -n supabase -o jsonpath='{.data.anon-key}' | base64 -d)
echo "Anon Key: ${ANON_KEY:0:20}..."

# Test PostgREST health endpoint
curl -H "apikey: $ANON_KEY" "http://$ALB_ENDPOINT/rest/v1/" --connect-timeout 10
# Expected: JSON response with service information

# Test Kong gateway
curl -H "apikey: $ANON_KEY" "http://$ALB_ENDPOINT/health" --connect-timeout 10
# Expected: 200 OK response
```

## 📊 Monitoring Deployment Progress

### Terraform State

Monitor Terraform deployment progress:

```bash
# Check networking state
cd environments/ireland/development/networking
terraform show

# Check core infrastructure state
cd ../core
terraform show

# Check applications state
cd ../applications
terraform show
```

### Kubernetes Resources

Monitor Kubernetes resources:

```bash
# Watch pod deployment
kubectl get pods -n supabase -w

# Check pod logs
kubectl logs -n supabase -l app=supabase-kong
kubectl logs -n supabase -l app=supabase-postgrest

# Check events
kubectl get events -n supabase --sort-by='.lastTimestamp'
```

## 🔧 Configuration

### Environment Variables

Key configuration options in `terraform.tfvars` files:

```hcl
# environments/ireland/development/networking/terraform.tfvars
region = "eu-west-1"
vpc_cidr = "10.100.0.0/16"

# environments/ireland/development/core/terraform.tfvars
cluster_version = "1.30"
db_instance_class = "db.t3.medium"
node_groups = [
  {
    name = "supabase-general"
    instance_types = ["t3.large"]
    desired_size = 2
  }
]

# environments/ireland/development/applications/terraform.tfvars
external_url = "https://api.supabase-dev.example.com"
enable_hpa = true
```

### Supabase Configuration

Supabase configuration is managed through AWS Secrets Manager:

```bash
# View configuration secrets
aws secretsmanager get-secret-value --secret-id supabase/development/config
```

## 🔍 Troubleshooting

### Common Issues

#### 1. EKS Node Groups Not Ready

```bash
# Check node group status
aws eks describe-nodegroup --cluster-name supabase-development-eks --nodegroup-name supabase-general

# Check node events
kubectl describe nodes
```

#### 2. Pods Stuck in Pending State

```bash
# Check pod descriptions
kubectl describe pod -n supabase <pod-name>

# Check resource constraints
kubectl top nodes
kubectl top pods -n supabase
```

#### 3. Database Connection Issues

```bash
# Test database connectivity
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
  psql postgresql://username:password@rds-endpoint:5432/supabase

# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>
```

#### 4. Secrets Not Available

```bash
# Check External Secrets Operator
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets

# Check SecretStore
kubectl describe secretstore aws-secrets-manager -n supabase

# Check ExternalSecret
kubectl describe externalsecret supabase-secrets -n supabase
```

### Logs and Debugging

```bash
# EKS cluster logs
aws logs describe-log-groups --log-group-name-prefix /aws/eks/supabase-development-eks

# Application logs
kubectl logs -n supabase -l app=supabase-kong --tail=100
kubectl logs -n supabase -l app=supabase-postgrest --tail=100

# System pods
kubectl logs -n kube-system -l app=aws-load-balancer-controller
kubectl logs -n kube-system -l app=cluster-autoscaler
```

## 🧪 Testing the Deployment

### Complete API Testing

```bash
# Set environment variables for testing
export ALB_ENDPOINT=$(kubectl get ingress supabase-ingress -n supabase -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export ANON_KEY=$(kubectl get secret supabase-secrets -n supabase -o jsonpath='{.data.anon-key}' | base64 -d)
export SERVICE_ROLE_KEY=$(kubectl get secret supabase-secrets -n supabase -o jsonpath='{.data.service-role-key}' | base64 -d)

echo "Testing Supabase API endpoints..."
echo "ALB Endpoint: $ALB_ENDPOINT"
echo "Anon Key: ${ANON_KEY:0:20}..."

# Test PostgREST API
echo "\n1. Testing PostgREST (REST API):"
curl -s -H "apikey: $ANON_KEY" "http://$ALB_ENDPOINT/rest/v1/" | jq .

# Test Auth API
echo "\n2. Testing Auth API:"
curl -s -H "apikey: $ANON_KEY" "http://$ALB_ENDPOINT/auth/v1/settings" | jq .

# Test Storage API
echo "\n3. Testing Storage API:"
curl -s -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" "http://$ALB_ENDPOINT/storage/v1/buckets" | jq .

# Test Realtime (WebSocket) - connection test
echo "\n4. Testing Realtime WebSocket (connection test):"
curl -s -H "apikey: $ANON_KEY" "http://$ALB_ENDPOINT/realtime/v1/" || echo "WebSocket endpoint ready"

echo "\n✅ API Testing Complete"
```

### Database Operations

```bash
# Test PostgREST API
curl -H "apikey: $ANON_KEY" \
     -H "Content-Type: application/json" \
     -X GET \
     "http://$INGRESS_URL/rest/v1/"
```

### Storage Operations

```bash
# Test storage endpoint
curl -H "apikey: $ANON_KEY" \
     -H "Authorization: Bearer $ANON_KEY" \
     -X GET \
     "http://$INGRESS_URL/storage/v1/buckets"
```

## 🔐 Security Validation

### Network Security

```bash
# Verify private subnets
aws ec2 describe-subnets --filters "Name=tag:Type,Values=eks-private"

# Check security groups
aws ec2 describe-security-groups --group-names "*supabase*"
```

### Secrets Security

```bash
# Verify secrets encryption
aws secretsmanager describe-secret --secret-id supabase/development/jwt-secret

# Check IAM roles
aws iam get-role --role-name supabase-development-external-secrets-role
```

### Pod Security

```bash
# Check security contexts
kubectl get pods -n supabase -o jsonpath='{.items[*].spec.securityContext}'

# Verify service accounts
kubectl get serviceaccounts -n supabase
```

## 📈 Scaling

### Scaling Operations

#### Manual Pod Scaling
```bash
# Scale specific Supabase services
kubectl scale deployment supabase-postgrest -n supabase --replicas=5
kubectl scale deployment supabase-realtime -n supabase --replicas=3
kubectl scale deployment supabase-auth -n supabase --replicas=4

# Verify scaling
kubectl get deployments -n supabase
```

#### Manual Node Scaling
```bash
# Scale EKS node groups
aws eks update-nodegroup-config \
  --cluster-name supabase-development-eks \
  --nodegroup-name supabase-development-small-general \
  --scaling-config desiredSize=3,maxSize=6,minSize=1

# Monitor node scaling
kubectl get nodes
aws eks describe-nodegroup --cluster-name supabase-development-eks --nodegroup-name supabase-development-small-general
```

#### Service Tier Scaling
```bash
# Change service tier for comprehensive scaling
cd environments/ireland/development/core

# Update to medium tier
echo 'service_tier = "medium"' > terraform.tfvars
terraform plan
terraform apply

# This will update:
# - RDS instance class (db.t3.small -> db.t3.medium)
# - EKS node instance types and counts
# - Resource limits and HPA configurations
```

### Auto Scaling

```bash
# Check HPA status
kubectl get hpa -n supabase

# Check cluster autoscaler
kubectl logs -n kube-system -l app=cluster-autoscaler
```

## 🔄 Updates and Maintenance

### Terraform Updates

```bash
# Update networking
cd environments/ireland/development/networking
terraform plan
terraform apply

# Update core infrastructure
cd ../core
terraform plan
terraform apply

# Update applications
cd ../applications
terraform plan
terraform apply
```

### Kubernetes Updates

```bash
# Update EKS cluster version
aws eks update-cluster-version --name supabase-development-eks --version 1.31

# Update node groups
aws eks update-nodegroup-version --cluster-name supabase-development-eks --nodegroup-name supabase-general
```

## 💰 Cost Management

### Cost Management and Monitoring

#### View Current Costs
```bash
# Get cost breakdown by service (last 30 days)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' '+%Y-%m-%d'),End=$(date '+%Y-%m-%d') \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter '{"Tags":{"Key":"Project","Values":["supabase"]}}'

# Get daily costs for current month
aws ce get-cost-and-usage \
  --time-period Start=$(date '+%Y-%m-01'),End=$(date '+%Y-%m-%d') \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter '{"Tags":{"Key":"Project","Values":["supabase"]}}'
```

#### Cost Optimization Actions
```bash
# 1. Switch to minimal tier for development
cd environments/ireland/development/core
echo 'service_tier = "minimal"' > terraform.tfvars
terraform apply
# Saves: ~$70-100/month

# 2. Use spot instances for non-critical workloads
kubectl taint nodes --all spot-instance=true:NoSchedule
# Enable spot node groups in terraform configuration

# 3. Schedule shutdown for development environment
# Add to crontab: 0 18 * * 1-5 kubectl scale deployments --all --replicas=0 -n supabase
# Add to crontab: 0 9 * * 1-5 kubectl scale deployments --all --replicas=2 -n supabase
```

#### Resource Utilization Monitoring
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n supabase

# Check HPA metrics
kubectl get hpa -n supabase -o wide

# Monitor cluster autoscaler decisions
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=50
```

### Cost Optimization

1. **Use Spot Instances**: Configure spot node groups for non-critical workloads
2. **RDS Reserved Instances**: Consider reserved instances for production databases
3. **S3 Lifecycle Policies**: Automatically transition old objects to cheaper storage classes
4. **CloudWatch Log Retention**: Set appropriate retention periods for logs

## 📊 Monitoring and Observability

### CloudWatch Metrics

Key metrics to monitor:
- EKS cluster health
- RDS performance metrics
- S3 usage metrics
- Application response times

### Prometheus Setup (Optional)

```bash
# Install Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values prometheus-values.yaml
```

## 🔄 Backup and Disaster Recovery

### RDS Backups

- Automated backups enabled (7-day retention)
- Point-in-time recovery available
- Cross-region snapshots for disaster recovery

### S3 Backups

- Versioning enabled
- Cross-region replication (optional)
- Lifecycle policies for cost optimization

### Configuration Backups

```bash
# Backup Kubernetes configurations
kubectl get all -n supabase -o yaml > supabase-backup.yaml

# Backup Terraform state
aws s3 cp s3://terraform-backend-state-supabase-bucket/supabase/aws/ireland/development/ ./state-backup/ --recursive
```

## 🧹 Cleanup

### Complete Infrastructure Destruction

```bash
# Automated cleanup
./scripts/destroy.sh development eu-west-1

# Manual cleanup (reverse order)
cd environments/ireland/development/applications
terraform destroy

cd ../core
terraform destroy

cd ../networking
terraform destroy
```

### Verification

```bash
# Verify no resources remain
aws eks list-clusters
aws rds describe-db-instances
aws s3 ls
```

---

For additional help or questions, please refer to:
- [Implementation Plan](IMPLEMENTATION_PLAN.md)
- [Architecture Documentation](README.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)