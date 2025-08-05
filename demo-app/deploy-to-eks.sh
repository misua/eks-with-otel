#!/bin/bash

# EKS Deployment Script for OpenTelemetry Demo App
# Usage: ./deploy-to-eks.sh [your-container-registry]

set -e

# Configuration
APP_NAME="eks-otel-demo"
NAMESPACE="default"
REGISTRY=${1:-"your-registry"}  # Use provided registry or default placeholder

echo "🚀 Deploying $APP_NAME to EKS"
echo "================================"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "   Make sure your kubeconfig is set up correctly"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"

# Build Docker image
echo "📦 Building Docker image..."
docker build -t $APP_NAME:latest .

# Tag for registry
if [ "$REGISTRY" != "your-registry" ]; then
    echo "🏷️  Tagging image for registry: $REGISTRY"
    docker tag $APP_NAME:latest $REGISTRY/$APP_NAME:latest
    
    echo "📤 Pushing to registry..."
    docker push $REGISTRY/$APP_NAME:latest
    
    # Update deployment file with actual registry
    sed "s|your-registry|$REGISTRY|g" k8s-deployment.yaml > k8s-deployment-temp.yaml
    DEPLOYMENT_FILE="k8s-deployment-temp.yaml"
else
    echo "⚠️  Using placeholder registry. Update k8s-deployment.yaml with your actual registry."
    DEPLOYMENT_FILE="k8s-deployment.yaml"
fi

# Deploy to Kubernetes
echo "🚢 Deploying to EKS..."
kubectl apply -f $DEPLOYMENT_FILE

# Clean up temp file
if [ -f "k8s-deployment-temp.yaml" ]; then
    rm k8s-deployment-temp.yaml
fi

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/$APP_NAME

# Show status
echo "📊 Deployment Status:"
kubectl get pods -l app=$APP_NAME
echo ""

# Show logs
echo "📋 Recent logs:"
kubectl logs -l app=$APP_NAME --tail=10
echo ""

# Show service info
echo "🌐 Service Information:"
kubectl get service ${APP_NAME}-service
echo ""

echo "✅ Deployment completed successfully!"
echo ""
echo "🔍 Useful commands:"
echo "   kubectl get pods -l app=$APP_NAME"
echo "   kubectl logs -l app=$APP_NAME -f"
echo "   kubectl port-forward service/${APP_NAME}-service 8080:80"
echo ""
echo "📊 Check observability in Grafana:"
echo "   - Logs: Loki data source"
echo "   - Traces: Tempo data source"
echo "   - Metrics: Prometheus data source"
