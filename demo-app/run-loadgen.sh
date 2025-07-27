#!/bin/bash

# Load Generator Script for EKS OpenTelemetry Demo App
# This script generates continuous traffic to populate your observability stack

set -e

# Configuration
DEMO_APP_URL=${1:-"http://localhost:8080"}
LOAD_DURATION=${2:-"5m"}
CONCURRENCY=${3:-"3"}

echo "🚀 EKS OpenTelemetry Demo - Load Generator"
echo "=========================================="
echo "Target URL: $DEMO_APP_URL"
echo "Duration: $LOAD_DURATION"
echo "Concurrency: $CONCURRENCY"
echo "=========================================="
echo ""

# Check if demo app is running
echo "🔍 Checking if demo app is accessible..."
if ! curl -s "$DEMO_APP_URL/health" > /dev/null; then
    echo "❌ Demo app is not accessible at $DEMO_APP_URL"
    echo "   Make sure the demo app is running:"
    echo "   - Local: go run cmd/api/main.go"
    echo "   - EKS: kubectl port-forward service/eks-otel-demo-service 8080:80"
    exit 1
fi

echo "✅ Demo app is accessible"
echo ""

# Build and run load generator
echo "🔨 Building load generator..."
go build -o loadgen ./cmd/loadgen

echo "🚀 Starting load generation..."
echo "   Press Ctrl+C to stop early"
echo ""

# Set environment variables and run
export DEMO_APP_URL="$DEMO_APP_URL"
export LOAD_DURATION="$LOAD_DURATION"
export CONCURRENCY="$CONCURRENCY"

./loadgen

echo ""
echo "🎯 Load generation completed!"
echo ""
echo "📊 Check your observability data:"
echo "   1. Grafana Dashboard"
echo "   2. Tempo - Distributed traces from all CRUD operations"
echo "   3. Loki - Structured logs with trace correlation"
echo "   4. Prometheus - HTTP metrics and custom metrics"
echo ""
echo "🔗 Useful Grafana queries:"
echo "   Loki: {service_name=\"eks-otel-demo\"}"
echo "   Tempo: Search by service name 'eks-otel-demo'"
