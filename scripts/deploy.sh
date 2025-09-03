#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT=${1:-development}
REGION=${2:-eu-west-1}

echo "🚀 Deploying Supabase infrastructure for environment: $ENVIRONMENT in region: $REGION"

if [ "$ENVIRONMENT" != "development" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo "❌ Error: Environment must be one of: development, staging, production"
    exit 1
fi

function check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    command -v terraform >/dev/null 2>&1 || { echo "❌ terraform is required but not installed."; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo "❌ aws cli is required but not installed."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
    command -v helm >/dev/null 2>&1 || { echo "❌ helm is required but not installed."; exit 1; }
    
    aws sts get-caller-identity >/dev/null 2>&1 || { echo "❌ AWS credentials not configured."; exit 1; }
    
    echo "✅ Prerequisites check passed"
}

function deploy_networking() {
    echo "🌐 Deploying networking infrastructure..."
    
    cd "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/networking"
    
    terraform init
    terraform plan -out=networking.tfplan
    terraform apply networking.tfplan
    
    echo "✅ Networking infrastructure deployed"
}

function deploy_core() {
    echo "🏗️ Deploying core infrastructure (EKS, RDS, S3, Secrets)..."
    
    cd "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/core"
    
    terraform init
    terraform plan -out=core.tfplan
    terraform apply core.tfplan
    
    echo "✅ Core infrastructure deployed"
}

function configure_kubectl() {
    echo "⚙️ Configuring kubectl..."
    
    CLUSTER_NAME=$(cd "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/core" && terraform output -raw cluster_name)
    
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
    
    echo "✅ kubectl configured for cluster: $CLUSTER_NAME"
}

function deploy_applications() {
    echo "📦 Deploying Supabase applications..."
    
    cd "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/applications"
    
    terraform init
    terraform plan -out=applications.tfplan
    terraform apply applications.tfplan
    
    echo "✅ Supabase applications deployed"
}

function verify_deployment() {
    echo "🔍 Verifying deployment..."
    
    echo "Checking cluster status..."
    kubectl get nodes
    
    echo "Checking Supabase pods..."
    kubectl get pods -n supabase
    
    echo "Checking services..."
    kubectl get svc -n supabase
    
    echo "Checking ingress..."
    kubectl get ingress -n supabase
    
    echo "✅ Deployment verification completed"
}

function show_tier_info() {
    echo "💰 Checking service tier configuration..."
    
    if [ -f "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/core/terraform.tfvars" ]; then
        SERVICE_TIER=$(grep "service_tier" "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/core/terraform.tfvars" | cut -d '"' -f 2 || echo "minimal")
        echo "📊 Current service tier: $SERVICE_TIER"
        
        # Show tier info
        "$SCRIPT_DIR/validate-tier.sh" "$SERVICE_TIER" | grep -E "(Description|Monthly Cost)" || true
        echo ""
    fi
}

function main() {
    echo "🎯 Starting Supabase infrastructure deployment"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo "Project Root: $PROJECT_ROOT"
    echo ""
    
    show_tier_info
    check_prerequisites
    deploy_networking
    deploy_core
    configure_kubectl
    deploy_applications
    verify_deployment
    
    echo ""
    echo "🎉 Supabase infrastructure deployment completed successfully!"
    echo ""
    echo "📊 Service Tier Information:"
    echo "  Current tier: $SERVICE_TIER"
    echo "  To change tiers: ./scripts/change-tier.sh <tier> $ENVIRONMENT"
    echo ""
    echo "🔗 Access Information:"
    echo "1. Get the Supabase API URL:"
    echo "   kubectl get ingress supabase-ingress -n supabase -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    echo ""
    echo "2. Get the anonymous API key:"
    echo "   kubectl get secret supabase-secrets -n supabase -o jsonpath='{.data.anon-key}' | base64 -d"
    echo ""
    echo "3. Test the API:"
    echo "   curl -H \"apikey: \$ANON_KEY\" https://\$API_URL/rest/v1/health"
    echo ""
    echo "4. Run comprehensive tests:"
    echo "   ./scripts/smoke-test.sh $ENVIRONMENT supabase"
}

main "$@"