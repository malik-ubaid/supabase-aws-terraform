#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT=${1:-development}
NAMESPACE=${2:-supabase}

echo "🧪 Running smoke tests for Supabase deployment"
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo ""

function wait_for_pods() {
    echo "⏳ Waiting for pods to be ready..."
    
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=supabase -n "$NAMESPACE" --timeout=300s
    
    echo "✅ All pods are ready"
}

function test_api_health() {
    echo "🏥 Testing API health endpoints..."
    
    # Get the ingress hostname
    INGRESS_HOST=$(kubectl get ingress supabase-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -z "$INGRESS_HOST" ]; then
        echo "⚠️  No ingress hostname found, testing via port-forward..."
        
        # Port forward to Kong service
        kubectl port-forward -n "$NAMESPACE" svc/supabase-kong 8080:8000 &
        PF_PID=$!
        
        sleep 5
        
        # Test local endpoint
        API_URL="http://localhost:8080"
        
        # Cleanup function
        cleanup() {
            kill $PF_PID 2>/dev/null || true
        }
        trap cleanup EXIT
    else
        API_URL="http://$INGRESS_HOST"
        echo "📡 Testing external endpoint: $API_URL"
    fi
    
    # Get anonymous key
    ANON_KEY=$(kubectl get secret supabase-secrets -n "$NAMESPACE" -o jsonpath='{.data.anon-key}' 2>/dev/null | base64 -d || echo "")
    
    if [ -z "$ANON_KEY" ]; then
        echo "⚠️  No anonymous key found, testing without authentication..."
        HEADERS=""
    else
        echo "🔑 Using anonymous key for authentication"
        HEADERS="-H 'apikey: $ANON_KEY' -H 'Authorization: Bearer $ANON_KEY'"
    fi
    
    # Test health endpoint
    echo "Testing health endpoint..."
    if eval "curl -f -s $HEADERS '$API_URL/rest/v1/health'" >/dev/null 2>&1; then
        echo "✅ Health endpoint responding"
    else
        echo "❌ Health endpoint not responding"
        return 1
    fi
    
    # Test PostgREST endpoint
    echo "Testing PostgREST endpoint..."
    if eval "curl -f -s $HEADERS '$API_URL/rest/v1/'" >/dev/null 2>&1; then
        echo "✅ PostgREST endpoint responding"
    else
        echo "⚠️  PostgREST endpoint not responding (may be normal if no tables exist)"
    fi
}

function test_database_connectivity() {
    echo "🗄️ Testing database connectivity..."
    
    # Get database credentials
    DB_HOST=$(kubectl get configmap supabase-config -n "$NAMESPACE" -o jsonpath='{.data.POSTGRES_HOST}' 2>/dev/null || echo "")
    DB_PORT=$(kubectl get configmap supabase-config -n "$NAMESPACE" -o jsonpath='{.data.POSTGRES_PORT}' 2>/dev/null || echo "5432")
    DB_NAME=$(kubectl get configmap supabase-config -n "$NAMESPACE" -o jsonpath='{.data.POSTGRES_DB}' 2>/dev/null || echo "supabase")
    
    if [ -z "$DB_HOST" ]; then
        echo "❌ Database host not found in configuration"
        return 1
    fi
    
    # Test database connectivity from a pod
    echo "Testing database connection to $DB_HOST:$DB_PORT..."
    
    kubectl run -it --rm db-test --image=postgres:15 --restart=Never -n "$NAMESPACE" -- \
        bash -c "pg_isready -h $DB_HOST -p $DB_PORT -d $DB_NAME" >/dev/null 2>&1 && \
        echo "✅ Database is accepting connections" || \
        echo "❌ Database connection failed"
}

function test_s3_connectivity() {
    echo "💾 Testing S3 connectivity..."
    
    S3_BUCKET=$(kubectl get configmap supabase-config -n "$NAMESPACE" -o jsonpath='{.data.S3_BUCKET}' 2>/dev/null || echo "")
    
    if [ -z "$S3_BUCKET" ]; then
        echo "❌ S3 bucket not found in configuration"
        return 1
    fi
    
    # Test S3 bucket accessibility
    aws s3 ls "s3://$S3_BUCKET" >/dev/null 2>&1 && \
        echo "✅ S3 bucket accessible" || \
        echo "❌ S3 bucket not accessible"
}

function test_secrets() {
    echo "🔐 Testing secrets availability..."
    
    # Check if secrets exist
    kubectl get secret supabase-secrets -n "$NAMESPACE" >/dev/null 2>&1 && \
        echo "✅ Supabase secrets available" || \
        echo "❌ Supabase secrets not found"
    
    kubectl get secret supabase-config -n "$NAMESPACE" >/dev/null 2>&1 && \
        echo "✅ Supabase config available" || \
        echo "❌ Supabase config not found"
}

function show_access_info() {
    echo ""
    echo "📋 Access Information"
    echo "===================="
    
    INGRESS_HOST=$(kubectl get ingress supabase-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not available")
    ANON_KEY=$(kubectl get secret supabase-secrets -n "$NAMESPACE" -o jsonpath='{.data.anon-key}' 2>/dev/null | base64 -d || echo "Not available")
    SERVICE_KEY=$(kubectl get secret supabase-secrets -n "$NAMESPACE" -o jsonpath='{.data.service-role-key}' 2>/dev/null | base64 -d || echo "Not available")
    
    echo "Supabase URL: http://$INGRESS_HOST"
    echo "API URL: http://$INGRESS_HOST/rest/v1"
    echo "Dashboard URL: http://$INGRESS_HOST/dashboard"
    echo ""
    echo "Anonymous Key: $ANON_KEY"
    echo "Service Role Key: $SERVICE_KEY"
    echo ""
    echo "Example API test:"
    echo "curl -H 'apikey: $ANON_KEY' http://$INGRESS_HOST/rest/v1/health"
}

function main() {
    echo "🎯 Starting Supabase smoke tests"
    echo ""
    
    wait_for_pods
    test_secrets
    test_database_connectivity
    test_s3_connectivity
    test_api_health
    show_access_info
    
    echo ""
    echo "🎉 Smoke tests completed!"
}

main "$@"