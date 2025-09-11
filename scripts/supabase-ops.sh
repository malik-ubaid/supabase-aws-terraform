#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OPERATION=${1:-help}
ENVIRONMENT=${2:-development}
REGION=${3:-eu-west-1}

function show_help() {
    echo "🚀 Supabase Operations Script"
    echo ""
    echo "Usage: $0 <operation> [environment] [region]"
    echo ""
    echo "Operations:"
    echo "  deploy       Deploy complete Supabase infrastructure"
    echo "  destroy      Destroy complete Supabase infrastructure"
    echo "  plan         Show deployment plan without applying"
    echo "  status       Show current deployment status"
    echo "  test-deploy  Test deployment logic (dry-run)"
    echo "  help         Show this help message"
    echo ""
    echo "Environment: development (default), staging, production"
    echo "Region: eu-west-1 (default)"
    echo ""
    echo "Examples:"
    echo "  $0 deploy development eu-west-1"
    echo "  $0 destroy development"
    echo "  $0 status"
    echo "  $0 plan"
    echo ""
    exit 0
}

function validate_inputs() {
    if [ "$ENVIRONMENT" != "development" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
        echo "❌ Error: Environment must be one of: development, staging, production"
        exit 1
    fi
    
    if [ "$OPERATION" != "deploy" ] && [ "$OPERATION" != "destroy" ] && [ "$OPERATION" != "plan" ] && [ "$OPERATION" != "status" ] && [ "$OPERATION" != "help" ] && [ "$OPERATION" != "test-deploy" ]; then
        echo "❌ Error: Operation must be one of: deploy, destroy, plan, status, test-deploy, help"
        exit 1
    fi
}

function check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    command -v terraform >/dev/null 2>&1 || { echo "❌ terraform is required but not installed."; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo "❌ aws cli is required but not installed."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
    command -v helm >/dev/null 2>&1 || { echo "❌ helm is required but not installed."; exit 1; }
    
    aws sts get-caller-identity >/dev/null 2>&1 || { echo "❌ AWS credentials not configured."; exit 1; }
    
    echo "✅ Prerequisites check passed"
}

function show_tier_info() {
    echo "💰 Checking service tier configuration..."
    
    if [ -f "$PROJECT_ROOT/stacks/core/terraform.tfvars" ]; then
        SERVICE_TIER=$(grep "service_tier" "$PROJECT_ROOT/stacks/core/terraform.tfvars" | cut -d '"' -f 2 2>/dev/null || echo "small")
        echo "📊 Current service tier: $SERVICE_TIER"
        echo ""
    fi
}

function deploy_networking() {
    echo "🌐 Deploying networking infrastructure..."
    
    cd "$PROJECT_ROOT/stacks/networking"
    
    terraform init
    if [ "$1" == "plan-only" ]; then
        terraform plan
        return 0
    fi
    
    # Check if there are any changes to apply
    echo "📝 Planning networking changes..."
    terraform plan -out=networking.tfplan
    
    # Check if plan has changes
    if terraform show networking.tfplan | grep -q "No changes"; then
        echo "✅ Networking infrastructure is already up to date"
        rm -f networking.tfplan
        return 0
    fi
    
    echo "🚀 Applying networking changes..."
    terraform apply networking.tfplan
    rm -f networking.tfplan
    
    echo "✅ Networking infrastructure deployed"
}

function deploy_core() {
    echo "🏗️ Deploying core infrastructure (EKS, RDS, S3, Secrets)..."
    
    cd "$PROJECT_ROOT/stacks/core"
    
    terraform init
    if [ "$1" == "plan-only" ]; then
        if ! check_terraform_state "networking"; then
            echo "❌ Cannot plan - networking not deployed"
            return 1
        fi
        terraform plan
        return 0
    fi
    
    echo "📝 Planning core infrastructure changes..."
    terraform plan -out=core.tfplan
    
    echo "🚀 Applying core infrastructure changes..."
    terraform apply core.tfplan
    rm -f core.tfplan
    
    echo "✅ Core infrastructure deployed"
}

function configure_kubectl() {
    echo "⚙️ Configuring kubectl..."
    
    CLUSTER_NAME=$(cd "$PROJECT_ROOT/stacks/core" && terraform output -raw cluster_name 2>/dev/null || echo "supabase-$ENVIRONMENT-eks")
    
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
    
    echo "✅ kubectl configured for cluster: $CLUSTER_NAME"
}

function deploy_applications() {
    echo "📦 Deploying Supabase applications..."
    
    cd "$PROJECT_ROOT/stacks/applications"
    
    terraform init
    if [ "$1" == "plan-only" ]; then
        if ! check_terraform_state "core"; then
            echo "❌ Cannot plan - core not deployed"
            return 1
        fi
        terraform plan
        return 0
    fi
    
    echo "📝 Planning applications changes..."
    terraform plan -out=applications.tfplan
    
    echo "🚀 Applying applications changes..."
    terraform apply applications.tfplan
    rm -f applications.tfplan
    
    echo "✅ Supabase applications deployed"
}

function verify_deployment() {
    echo "🔍 Verifying deployment..."
    
    echo "Checking cluster status..."
    kubectl get nodes || echo "⚠️ Could not get nodes"
    
    echo "Checking Supabase pods..."
    kubectl get pods -n supabase || echo "⚠️ Could not get pods in supabase namespace"
    
    echo "Checking services..."
    kubectl get svc -n supabase || echo "⚠️ Could not get services in supabase namespace"
    
    echo "Checking ingress..."
    kubectl get ingress -n supabase || echo "⚠️ Could not get ingress in supabase namespace"
    
    echo "✅ Deployment verification completed"
}

function destroy_applications() {
    echo "🗑️ Destroying applications..."
    
    cd "$PROJECT_ROOT/stacks/applications"
    
    terraform init
    terraform destroy -auto-approve
    
    echo "✅ Applications destroyed"
}

function destroy_core() {
    echo "🗑️ Destroying core infrastructure..."
    
    cd "$PROJECT_ROOT/stacks/core"
    
    terraform init
    terraform destroy -auto-approve
    
    echo "✅ Core infrastructure destroyed"
}

function destroy_networking() {
    echo "🗑️ Destroying networking infrastructure..."
    
    cd "$PROJECT_ROOT/stacks/networking"
    
    terraform init
    terraform destroy -auto-approve
    
    echo "✅ Networking infrastructure destroyed"
}

function cleanup_kubeconfig() {
    echo "🧹 Cleaning up kubectl configuration..."
    
    CLUSTER_NAME="supabase-$ENVIRONMENT-eks"
    
    kubectl config delete-cluster "$CLUSTER_NAME" 2>/dev/null || true
    kubectl config delete-context "$CLUSTER_NAME" 2>/dev/null || true
    kubectl config unset users."$CLUSTER_NAME" 2>/dev/null || true
    
    echo "✅ kubectl configuration cleaned"
}

function get_stack_status() {
    local stack=$1
    local stack_dir="$PROJECT_ROOT/stacks/$stack"
    
    if [ ! -d "$stack_dir/.terraform" ]; then
        echo "❌ Not initialized"
        return 1
    fi
    
    cd "$stack_dir"
    if terraform state list >/dev/null 2>&1 && [ $(terraform state list 2>/dev/null | wc -l) -gt 0 ]; then
        echo "✅ Deployed ($(terraform state list 2>/dev/null | wc -l) resources)"
        return 0
    else
        echo "❌ Not deployed"
        return 1
    fi
}

function show_status() {
    echo "📊 Checking infrastructure status..."
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo ""
    
    show_tier_info
    
    echo "🔍 Stack Status & Dependencies:"
    echo ""
    
    # Check networking
    echo -n "  1️⃣ Networking: "
    NETWORKING_STATUS=$(get_stack_status "networking")
    echo "$NETWORKING_STATUS"
    
    # Check core with dependency info
    echo -n "  2️⃣ Core: "
    CORE_STATUS=$(get_stack_status "core")
    echo "$CORE_STATUS"
    if [[ "$NETWORKING_STATUS" != *"✅"* ]]; then
        echo "    ⚠️  Depends on: Networking (not ready)"
    elif [[ "$CORE_STATUS" == *"✅"* ]]; then
        echo "    ✅ All dependencies satisfied"
    else
        echo "    ✅ Dependencies ready - can be deployed"
    fi
    
    # Check applications with dependency info
    echo -n "  3️⃣ Applications: "
    APPS_STATUS=$(get_stack_status "applications")
    echo "$APPS_STATUS"
    if [[ "$CORE_STATUS" != *"✅"* ]]; then
        echo "    ⚠️  Depends on: Core (not ready)"
    elif [[ "$APPS_STATUS" == *"✅"* ]]; then
        echo "    ✅ All dependencies satisfied"
    else
        echo "    ✅ Dependencies ready - can be deployed"
    fi
    
    echo ""
    echo "🎯 Next Actions:"
    if [[ "$NETWORKING_STATUS" != *"✅"* ]]; then
        echo "  → Deploy networking first: ./scripts/supabase-ops.sh deploy"
    elif [[ "$CORE_STATUS" != *"✅"* ]]; then
        echo "  → Deploy core next: cd stacks/core && terraform apply"
    elif [[ "$APPS_STATUS" != *"✅"* ]]; then
        echo "  → Deploy applications: cd stacks/applications && terraform apply"
    else
        echo "  → All stacks deployed! Infrastructure is ready."
    fi
    
    echo ""
    echo "🔗 Cluster Status:"
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅ Connected to cluster"
        kubectl get nodes --no-headers 2>/dev/null | wc -l | xargs echo "  Nodes:" || echo "  Nodes: 0"
        kubectl get pods -n supabase --no-headers 2>/dev/null | wc -l | xargs echo "  Supabase pods:" || echo "  Supabase pods: 0"
    else
        echo "❌ Not connected to cluster"
        if [[ "$CORE_STATUS" == *"✅"* ]]; then
            echo "💡 Try: aws eks update-kubeconfig --name supabase-$ENVIRONMENT-eks --region $REGION"
        fi
    fi
}

function deploy_full() {
    echo "🎯 Starting full Supabase infrastructure deployment"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo "Project Root: $PROJECT_ROOT"
    echo ""
    
    show_tier_info
    check_prerequisites
    
    echo ""
    echo "🔍 Checking deployment dependencies..."
    
    # Always deploy networking first
    echo ""
    echo "1️⃣ Deploying networking stack..."
    deploy_networking
    if [ $? -ne 0 ]; then
        echo "❌ Networking deployment failed. Aborting."
        exit 1
    fi
    
    # Deploy core only after networking is ready
    echo ""
    echo "2️⃣ Deploying core stack..."
    if check_terraform_state "networking"; then
        deploy_core
        if [ $? -ne 0 ]; then
            echo "❌ Core deployment failed. Aborting."
            exit 1
        fi
    else
        echo "❌ Networking stack not properly deployed. Cannot continue."
        exit 1
    fi
    
    # Configure kubectl after EKS is ready
    echo ""
    echo "⚙️ Configuring cluster access..."
    configure_kubectl
    if [ $? -ne 0 ]; then
        echo "⚠️ kubectl configuration failed, but continuing..."
    fi
    
    # Deploy applications only after core is ready
    echo ""
    echo "3️⃣ Deploying applications stack..."
    if check_terraform_state "core"; then
        deploy_applications
        if [ $? -ne 0 ]; then
            echo "❌ Applications deployment failed. Infrastructure partially deployed."
            echo "💡 Fix the issue and run the command again to complete deployment."
            exit 1
        fi
    else
        echo "❌ Core stack not properly deployed. Cannot deploy applications."
        exit 1
    fi
    
    # Verify everything is working
    echo ""
    echo "🔍 Verifying deployment..."
    verify_deployment
    
    echo ""
    echo "🎉 Supabase infrastructure deployment completed successfully!"
    echo ""
    echo "📊 Deployment Summary:"
    echo "  ✅ Networking: $(get_stack_status "networking")"
    echo "  ✅ Core: $(get_stack_status "core")"  
    echo "  ✅ Applications: $(get_stack_status "applications")"
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
}

function destroy_full() {
    echo "🗑️ Destroying Supabase infrastructure for environment: $ENVIRONMENT in region: $REGION"
    echo ""
    echo "⚠️  WARNING: This will destroy all infrastructure and data!"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo ""
    
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "❌ Destruction cancelled"
        exit 1
    fi
    
    echo "🎯 Starting Supabase infrastructure destruction"
    
    destroy_applications
    cleanup_kubeconfig
    destroy_core
    destroy_networking
    
    echo ""
    echo "💀 Supabase infrastructure destruction completed!"
    echo ""
    echo "Note: Some resources like S3 buckets may have retention policies."
    echo "Check AWS console to ensure all resources are properly cleaned up."
}

function check_stack_dependencies() {
    local stack=$1
    
    case $stack in
        "networking")
            return 0  # No dependencies
            ;;
        "core")
            # Check if networking is deployed
            if ! check_terraform_state "networking"; then
                echo "⚠️  Core stack requires networking to be deployed first"
                return 1
            fi
            return 0
            ;;
        "applications")
            # Check if core is deployed
            if ! check_terraform_state "core"; then
                echo "⚠️  Applications stack requires core to be deployed first"
                return 1
            fi
            return 0
            ;;
    esac
}

function check_terraform_state() {
    local stack=$1
    local stack_dir="$PROJECT_ROOT/stacks/$stack"
    
    if [ ! -d "$stack_dir/.terraform" ]; then
        return 1
    fi
    
    cd "$stack_dir"
    if terraform state list >/dev/null 2>&1 && [ $(terraform state list | wc -l) -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

function plan_deployment() {
    echo "📋 Planning Supabase infrastructure deployment"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo ""
    
    show_tier_info
    
    echo "🔍 Checking stack dependencies..."
    
    # Plan networking (always possible)
    echo ""
    echo "🌐 Networking plan:"
    deploy_networking "plan-only"
    
    # Plan core only if networking is deployed or show dependency message
    echo ""
    echo "🏗️ Core infrastructure plan:"
    if check_terraform_state "networking"; then
        deploy_core "plan-only"
    else
        echo "❌ Cannot plan core stack - networking must be deployed first"
        echo "💡 Run: ./scripts/supabase-ops.sh deploy to deploy in correct order"
        echo "💡 Or deploy networking first: cd stacks/networking && terraform apply"
    fi
    
    # Plan applications only if core is deployed or show dependency message  
    echo ""
    echo "📦 Applications plan:"
    if check_terraform_state "core"; then
        deploy_applications "plan-only"
    else
        echo "❌ Cannot plan applications stack - core must be deployed first"
        echo "💡 Deploy networking and core first, then applications will be plannable"
    fi
    
    echo ""
    echo "📋 Planning completed."
    echo ""
    echo "🎯 Deployment Order:"
    echo "  1. Networking (✅ Can be deployed)"
    echo "  2. Core ($(check_terraform_state "networking" && echo "✅ Ready" || echo "⏳ Requires networking"))"
    echo "  3. Applications ($(check_terraform_state "core" && echo "✅ Ready" || echo "⏳ Requires core"))"
    echo ""
    echo "💡 Use './scripts/supabase-ops.sh deploy' to deploy all stacks in correct order"
}

# Main execution
case $OPERATION in
    help)
        show_help
        ;;
    deploy)
        validate_inputs
        deploy_full
        ;;
    destroy)
        validate_inputs
        destroy_full
        ;;
    plan)
        validate_inputs
        plan_deployment
        ;;
    status)
        validate_inputs
        show_status
        ;;
    test-deploy)
        validate_inputs
        echo "🧪 Testing deployment logic (dry-run mode)..."
        echo ""
        show_tier_info
        echo "🔍 Checking deployment dependencies..."
        echo ""
        echo "1️⃣ Networking: $(check_terraform_state "networking" && echo "✅ Ready to skip" || echo "⏳ Will deploy")"
        echo "2️⃣ Core: $(check_terraform_state "core" && echo "✅ Ready to skip" || (check_terraform_state "networking" && echo "⏳ Will deploy" || echo "❌ Blocked - needs networking"))"
        echo "3️⃣ Applications: $(check_terraform_state "applications" && echo "✅ Ready to skip" || (check_terraform_state "core" && echo "⏳ Will deploy" || echo "❌ Blocked - needs core"))"
        echo ""
        echo "🧪 Test completed - use 'deploy' to run actual deployment"
        ;;
    *)
        echo "❌ Unknown operation: $OPERATION"
        show_help
        ;;
esac