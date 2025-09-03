#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICE_TIER=${1:-minimal}

echo "🔍 Validating service tier: $SERVICE_TIER"

function validate_tier() {
    echo "📋 Service Tier: $SERVICE_TIER"
    echo "================================"
    
    # Extract tier information using yq (or python if yq not available)
    if command -v yq >/dev/null 2>&1; then
        TIER_INFO=$(yq eval ".tiers.$SERVICE_TIER" "$PROJECT_ROOT/service-tiers.yaml")
        DESCRIPTION=$(yq eval ".tiers.$SERVICE_TIER.description" "$PROJECT_ROOT/service-tiers.yaml")
        COST_ESTIMATE=$(yq eval ".tiers.$SERVICE_TIER.monthly_cost_estimate" "$PROJECT_ROOT/service-tiers.yaml")
        USE_CASES=$(yq eval ".tiers.$SERVICE_TIER.use_cases[]" "$PROJECT_ROOT/service-tiers.yaml")
    else
        # Fallback to python
        TIER_INFO=$(python3 -c "
import yaml
with open('$PROJECT_ROOT/service-tiers.yaml', 'r') as f:
    data = yaml.safe_load(f)
    tier = data['tiers']['$SERVICE_TIER']
    print(f\"Description: {tier['description']}\")
    print(f\"Monthly Cost: {tier['monthly_cost_estimate']}\")
    print(f\"Use Cases: {', '.join(tier['use_cases'])}\")
")
    fi
    
    if [ "$TIER_INFO" = "null" ] || [ -z "$TIER_INFO" ]; then
        echo "❌ Invalid service tier: $SERVICE_TIER"
        echo "Valid tiers: minimal, small, medium, large, xlarge"
        exit 1
    fi
    
    echo "Description: $DESCRIPTION"
    echo "Estimated Monthly Cost: $COST_ESTIMATE"
    echo "Use Cases: $USE_CASES"
    echo ""
}

function show_tier_resources() {
    echo "📊 Resource Allocation for $SERVICE_TIER tier:"
    echo "=============================================="
    
    python3 -c "
import yaml
import json

with open('$PROJECT_ROOT/service-tiers.yaml', 'r') as f:
    data = yaml.safe_load(f)
    tier = data['tiers']['$SERVICE_TIER']
    
print('EKS Configuration:')
for ng in tier['eks']['node_groups']:
    print(f\"  - Node Group: {ng['name']}\")
    print(f\"    Instance Types: {', '.join(ng['instance_types'])}\")
    print(f\"    Capacity Type: {ng['capacity_type']}\")
    print(f\"    Size: {ng['min_size']}-{ng['desired_size']}-{ng['max_size']} (min-desired-max)\")
    print(f\"    Disk Size: {ng['disk_size']}GB\")
    print()

print('RDS Configuration:')
rds = tier['rds']
print(f\"  Instance Class: {rds['instance_class']}\")
print(f\"  Storage: {rds['allocated_storage']}GB (max: {rds['max_allocated_storage']}GB)\")
print(f\"  Multi-AZ: {rds['multi_az']}\")
print(f\"  Backup Retention: {rds['backup_retention_period']} days\")
print(f\"  Performance Insights: {rds['performance_insights_enabled']}\")
print()

print('Supabase Resources:')
supabase = tier['supabase']
for component, resources in supabase['resources'].items():
    print(f\"  {component.capitalize()}:\")
    print(f\"    Requests: {resources['requests']['cpu']} CPU, {resources['requests']['memory']} Memory\")
    print(f\"    Limits: {resources['limits']['cpu']} CPU, {resources['limits']['memory']} Memory\")

print()
print('Replicas:')
for component, count in supabase['replicas'].items():
    print(f\"  {component.capitalize()}: {count} replica(s)\")

if supabase['enable_hpa'] and 'hpa' in supabase:
    print()
    print('HPA Configuration:')
    for component, hpa in supabase['hpa'].items():
        print(f\"  {component.capitalize()}: {hpa['min']}-{hpa['max']} replicas (CPU target: {hpa['cpu_target']}%)\")
"
}

function show_cost_comparison() {
    echo ""
    echo "💰 Cost Comparison Across Tiers:"
    echo "================================"
    
    python3 -c "
import yaml

with open('$PROJECT_ROOT/service-tiers.yaml', 'r') as f:
    data = yaml.safe_load(f)
    
print('Tier'.ljust(10) + 'Monthly Cost'.ljust(15) + 'Description')
print('-' * 60)

for tier_name, tier_data in data['tiers'].items():
    current = ' <-- CURRENT' if tier_name == '$SERVICE_TIER' else ''
    print(f\"{tier_name.ljust(10)}{tier_data['monthly_cost_estimate'].ljust(15)}{tier_data['description']}{current}\")
"
}

function show_recommendations() {
    echo ""
    echo "💡 Recommendations:"
    echo "=================="
    
    case $SERVICE_TIER in
        "minimal")
            echo "✅ Perfect for development and testing"
            echo "⚠️  Not suitable for production workloads"
            echo "💡 Consider 'small' tier for staging environments"
            ;;
        "small")
            echo "✅ Good for small production workloads"
            echo "✅ Suitable for staging environments"
            echo "💡 Monitor performance and scale to 'medium' if needed"
            ;;
        "medium")
            echo "✅ Balanced production setup"
            echo "✅ Good for most business applications"
            echo "💡 Monitor costs and downgrade to 'small' if over-provisioned"
            ;;
        "large")
            echo "✅ High-performance production setup"
            echo "⚠️  Higher costs - ensure workload justifies resources"
            echo "💡 Consider cost optimization with reserved instances"
            ;;
        "xlarge")
            echo "✅ Enterprise-scale deployment"
            echo "⚠️  Significant costs - only for high-scale applications"
            echo "💡 Implement comprehensive monitoring and cost controls"
            ;;
    esac
}

function main() {
    validate_tier
    show_tier_resources
    show_cost_comparison
    show_recommendations
    
    echo ""
    echo "🎯 To deploy with this tier:"
    echo "  1. Set service_tier = \"$SERVICE_TIER\" in terraform.tfvars files"
    echo "  2. Run: ./scripts/deploy.sh development eu-west-1"
    echo ""
    echo "✅ Tier validation completed!"
}

main "$@"