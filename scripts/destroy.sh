#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT=${1:-development}
REGION=${2:-eu-west-1}

echo "🗑️ Destroying Supabase infrastructure for environment: $ENVIRONMENT in region: $REGION"

if [ "$ENVIRONMENT" != "development" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo "❌ Error: Environment must be one of: development, staging, production"
    exit 1
fi

echo "⚠️  WARNING: This will destroy all infrastructure and data!"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ Destruction cancelled"
    exit 1
fi

function destroy_applications() {
    echo "🗑️ Destroying applications..."
    
    cd "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/applications"
    
    if [ -f "applications.tfplan" ]; then
        rm applications.tfplan
    fi
    
    terraform init
    terraform destroy -auto-approve
    
    echo "✅ Applications destroyed"
}

function destroy_core() {
    echo "🗑️ Destroying core infrastructure..."
    
    cd "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/core"
    
    if [ -f "core.tfplan" ]; then
        rm core.tfplan
    fi
    
    terraform init
    terraform destroy -auto-approve
    
    echo "✅ Core infrastructure destroyed"
}

function destroy_networking() {
    echo "🗑️ Destroying networking infrastructure..."
    
    cd "$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/networking"
    
    if [ -f "networking.tfplan" ]; then
        rm networking.tfplan
    fi
    
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

function main() {
    echo "🎯 Starting Supabase infrastructure destruction"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $REGION"
    echo ""
    
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

main "$@"