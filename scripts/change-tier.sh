#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NEW_TIER=${1}
ENVIRONMENT=${2:-development}

if [ -z "$NEW_TIER" ]; then
    echo "❌ Usage: $0 <tier> [environment]"
    echo "Available tiers: minimal, small, medium, large, xlarge"
    exit 1
fi

echo "🔄 Changing service tier to: $NEW_TIER for environment: $ENVIRONMENT"

function validate_tier() {
    case $NEW_TIER in
        "minimal"|"small"|"medium"|"large"|"xlarge")
            echo "✅ Valid tier: $NEW_TIER"
            ;;
        *)
            echo "❌ Invalid tier: $NEW_TIER"
            echo "Valid tiers: minimal, small, medium, large, xlarge"
            exit 1
            ;;
    esac
}

function show_tier_info() {
    echo ""
    echo "📋 Tier Information:"
    echo "==================="
    
    "$SCRIPT_DIR/validate-tier.sh" "$NEW_TIER"
}

function update_tfvars() {
    echo ""
    echo "📝 Updating terraform.tfvars files..."
    
    # Update core terraform.tfvars
    CORE_TFVARS="$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/core/terraform.tfvars"
    if [ -f "$CORE_TFVARS" ]; then
        sed -i.bak "s/service_tier = \".*\"/service_tier = \"$NEW_TIER\"/" "$CORE_TFVARS"
        echo "✅ Updated core terraform.tfvars"
    else
        echo "❌ Core terraform.tfvars not found at $CORE_TFVARS"
    fi
    
    # Update applications terraform.tfvars
    APPS_TFVARS="$PROJECT_ROOT/environments/ireland/$ENVIRONMENT/applications/terraform.tfvars"
    if [ -f "$APPS_TFVARS" ]; then
        sed -i.bak "s/service_tier = \".*\"/service_tier = \"$NEW_TIER\"/" "$APPS_TFVARS"
        echo "✅ Updated applications terraform.tfvars"
    else
        echo "❌ Applications terraform.tfvars not found at $APPS_TFVARS"
    fi
}

function show_plan_command() {
    echo ""
    echo "🚀 Next Steps:"
    echo "============="
    echo "1. Review the changes:"
    echo "   cd environments/ireland/$ENVIRONMENT/core"
    echo "   terraform plan"
    echo ""
    echo "2. Apply the changes:"
    echo "   terraform apply"
    echo ""
    echo "3. Update applications:"
    echo "   cd ../applications"
    echo "   terraform plan"
    echo "   terraform apply"
    echo ""
    echo "⚠️  Note: Changing tiers may cause downtime and resource recreation"
    echo "💡 For production environments, plan maintenance windows accordingly"
}

function main() {
    validate_tier
    show_tier_info
    
    echo ""
    read -p "Do you want to update terraform.tfvars files? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        update_tfvars
        show_plan_command
    else
        echo "❌ Tier change cancelled"
        exit 0
    fi
    
    echo ""
    echo "✅ Service tier changed to: $NEW_TIER"
}

main "$@"