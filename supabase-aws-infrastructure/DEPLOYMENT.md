# Supabase on AWS - Deployment Guide

This guide provides step-by-step instructions for deploying Supabase on AWS using Terraform and Kubernetes.

## 📋 Prerequisites

### Required Tools

Ensure you have the following tools installed:

```bash
# Terraform (>= 1.12)
terraform --version

# AWS CLI (>= 2.0)
aws --version

# kubectl (>= 1.28)
kubectl version --client

# Helm (>= 3.12)
helm version
```

### AWS Prerequisites

1. **AWS Account**: Active AWS account with appropriate permissions
2. **AWS Credentials**: Configure AWS CLI with credentials
3. **S3 Backend Bucket**: Create S3 bucket for Terraform state

```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity

# Create S3 bucket for Terraform state (adjust bucket name)
aws s3 mb s3://terraform-backend-state-supabase-bucket --region eu-west-1
aws s3api put-bucket-versioning --bucket terraform-backend-state-supabase-bucket --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket terraform-backend-state-supabase-bucket --server-side-encryption-configuration '{
  "Rules": [
    {
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }
  ]
}'
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

```bash
cd environments/ireland/development/networking

# Initialize Terraform
terraform init

# Review the plan
terraform plan -out=networking.tfplan

# Apply changes
terraform apply networking.tfplan
```

**Expected Resources Created:**
- VPC with DNS support
- Public subnets (3 AZs)
- EKS private subnets (3 AZs) 
- RDS private subnets (3 AZs)
- Internet Gateway
- NAT Gateway
- Route tables and associations
- VPC endpoints for AWS services
- Security groups
- VPC Flow Logs

## 2. Deploy Core Infrastructure

```bash
cd ../core

# Initialize Terraform
terraform init

# Review the plan
terraform plan -out=core.tfplan

# Apply changes
terraform apply core.tfplan
```

**Expected Resources Created:**
- EKS cluster with managed node groups
- RDS PostgreSQL instance (Multi-AZ)
- S3 bucket for Supabase storage
- AWS Secrets Manager secrets
- IAM roles and policies
- KMS keys for encryption
- CloudWatch log groups

## 3. Configure kubectl

```bash
# Update kubeconfig for the EKS cluster
aws eks update-kubeconfig --name supabase-development-eks --region eu-west-1

# Verify cluster access
kubectl get nodes
```

## 4. Deploy Supabase Applications

```bash
cd ../applications

# Initialize Terraform
terraform init

# Review the plan
terraform plan -out=applications.tfplan

# Apply changes
terraform apply applications.tfplan
```

**Expected Resources Created:**
- External Secrets Operator
- Kubernetes secrets and config maps
- Supabase services (Kong, PostgREST, Realtime, Auth, Storage)
- Horizontal Pod Autoscalers
- Ingress configuration
- Service accounts with IRSA

## 5. Verify Deployment

```bash
# Check cluster status
kubectl get nodes

# Check Supabase pods
kubectl get pods -n supabase

# Check services
kubectl get svc -n supabase

# Check ingress
kubectl get ingress -n supabase

# Run smoke tests
./scripts/smoke-test.sh development supabase
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

### API Health Check

```bash
# Get ingress URL
INGRESS_URL=$(kubectl get ingress supabase-ingress -n supabase -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Get anonymous key
ANON_KEY=$(kubectl get secret supabase-secrets -n supabase -o jsonpath='{.data.anon-key}' | base64 -d)

# Test health endpoint
curl -H "apikey: $ANON_KEY" "http://$INGRESS_URL/rest/v1/health"
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

### Manual Scaling

```bash
# Scale node groups
aws eks update-nodegroup-config \
  --cluster-name supabase-development-eks \
  --nodegroup-name supabase-general \
  --scaling-config desiredSize=5,maxSize=10,minSize=2

# Scale application deployments
kubectl scale deployment supabase-postgrest -n supabase --replicas=5
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

### Cost Monitoring

```bash
# Estimate costs by resource tags
aws ce get-dimension-values \
  --dimension SERVICE \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --filter '{"Tags":{"Key":"Project","Values":["supabase"]}}'
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