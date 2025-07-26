#!/bin/bash

# EKS with OpenTelemetry CRUD Infrastructure Setup
# This script actually creates the infrastructure

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

CLUSTER_NAME="eks-otel-crud"
REGION="us-west-2"

# Check prerequisites
print_step "Checking prerequisites..."
for cmd in eksctl kubectl helm aws; do
    if ! command -v $cmd &> /dev/null; then
        print_error "$cmd is not installed"
        exit 1
    fi
done
print_success "All prerequisites installed"

# Configuration
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "Configuration:"
echo "  Cluster: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  Account: $ACCOUNT_ID"

# Step 1: Create EKS Cluster
print_step "Creating EKS cluster..."
print_warning "This will take 15-20 minutes..."
echo ""

# Check if cluster already exists
if eksctl get cluster --name $CLUSTER_NAME --region $REGION &>/dev/null; then
    echo "✅ Cluster $CLUSTER_NAME already exists, skipping creation"
else
    echo "Creating EKS cluster..."
    echo ""
    echo "⚠️  IMPORTANT: Ensure your IAM user has these permissions:"
    echo "   - iam:CreateServiceLinkedRole"
    echo "   - iam:GetOpenIDConnectProvider"
    echo "   - iam:ListOpenIDConnectProviders"
    echo "   - iam:CreateOpenIDConnectProvider"
    echo "   - iam:TagOpenIDConnectProvider"
    echo "   - iam:DeleteOpenIDConnectProvider"
    echo "   - ssm:GetParameter"
    echo "   - ssm:GetParameters"
    echo "   - ssm:DescribeParameters"
    echo "   - autoscaling:*"
    echo ""
    read -p "Continue with EKS cluster creation? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        eksctl create cluster -f eks-infrastructure/eks-cluster.yaml
    else
        echo "Cluster creation cancelled"
        exit 1
    fi
fi
print_success "EKS cluster created successfully"

# Step 2: Configuring kubectl
print_step "Configuring kubectl..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verify cluster is accessible
if ! kubectl get nodes &>/dev/null; then
    echo "❌ Failed to connect to cluster. Check IAM permissions and cluster status"
    exit 1
fi

# Step 3: Install Helm repositories
print_step "Setting up Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true

# Retry mechanism for Helm repo updates
MAX_RETRIES=3
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if helm repo update --timeout 120s 2>/dev/null; then
        print_success "Helm repositories updated successfully"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        print_warning "Helm repo update failed, retry $RETRY_COUNT/$MAX_RETRIES..."
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            print_error "Helm repo update failed after $MAX_RETRIES attempts"
            echo "⚠️ Proceeding with cached data..."
            echo "⚠️ If installations fail, you may need to manually update Helm repos with 'helm repo update'"
        else
            sleep 10
        fi
    fi
done

# Step 4: Deploy Prometheus and Grafana for monitoring
print_step "Deploying Prometheus and Grafana..."
echo "Deploying Prometheus and Grafana..."
if ! helm list -n monitoring 2>/dev/null | grep -q prometheus; then
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Wait for namespace to be ready
    sleep 5
    
    # Deploy with values file if it exists, otherwise use inline configuration
    if [ -f "eks-infrastructure/monitoring/prometheus-values.yaml" ]; then
        helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f eks-infrastructure/monitoring/prometheus-values.yaml
    else
        helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp2 \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
            --set grafana.persistence.enabled=true \
            --set grafana.persistence.size=5Gi \
            --set grafana.service.type=LoadBalancer
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Prometheus and Grafana deployed successfully"
    else
        print_error "Failed to deploy Prometheus and Grafana"
        # Show last 20 lines of logs for debugging
        echo "Checking recent logs for debugging..."
        kubectl get pods -n monitoring 2>/dev/null | head -10 || echo "No monitoring pods found"
        exit 1
    fi
else
    echo "✅ Prometheus and Grafana already deployed, skipping"
fi

# Wait for Prometheus and Grafana to be ready
print_step "Waiting for Prometheus and Grafana to be ready..."
echo "Waiting for Prometheus to be ready..."

# Try to find any deployment in monitoring namespace that might be related to Prometheus
PROMETHEUS_DEPLOYMENT=$(kubectl get deployments -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$PROMETHEUS_DEPLOYMENT" ]; then
    PROMETHEUS_DEPLOYMENT=$(kubectl get deployments -n monitoring -l app.kubernetes.io/component=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi
if [ -z "$PROMETHEUS_DEPLOYMENT" ]; then
    echo "⚠️ Could not find Prometheus deployment, waiting for any deployment in monitoring namespace..."
    kubectl wait --for=condition=available deployment -l app.kubernetes.io/part-of=kube-prometheus-stack -n monitoring --timeout=600s 2>/dev/null || echo "⚠️ Timeout waiting for Prometheus, continuing anyway..."
else
    echo "Found Prometheus deployment: $PROMETHEUS_DEPLOYMENT"
    kubectl wait --for=condition=available deployment/$PROMETHEUS_DEPLOYMENT -n monitoring --timeout=600s || echo "⚠️ Timeout waiting for Prometheus, continuing anyway..."
fi
print_success "Monitoring stack deployed"

# Step 4.5: Deploy Grafana Tempo for distributed tracing
print_step "Deploying Grafana Tempo for distributed tracing..."
echo "Deploying Grafana Tempo..."

# Clean up any existing Tempo installation to ensure a clean deployment
if helm list -n tracing 2>/dev/null | grep -q tempo; then
    print_warning "Found existing Tempo installation, cleaning up for fresh deployment..."
    helm uninstall tempo -n tracing 2>/dev/null || print_warning "Could not uninstall existing Tempo release."
    # Wait for resources to be cleaned up
    print_step "Waiting for old Tempo resources to be terminated..."
    sleep 15
fi

# Ensure tracing namespace exists
kubectl create namespace tracing --dry-run=client -o yaml | kubectl apply -f -

# Deploy Tempo with robust configuration using the corrected values file
if [ -f "eks-infrastructure/monitoring/tempo-values-corrected.yaml" ]; then
    print_step "Installing Grafana Tempo with corrected values file..."
    helm install tempo grafana/tempo -n tracing -f eks-infrastructure/monitoring/tempo-values-corrected.yaml
else
    print_error "Corrected Tempo values file not found! Please ensure 'tempo-values-corrected.yaml' exists."
    exit 1
fi

if [ $? -eq 0 ]; then
    print_success "Grafana Tempo deployed successfully"
else
    print_error "Failed to deploy Grafana Tempo"
    echo "Checking recent logs for debugging..."
    kubectl get pods -n tracing 2>/dev/null | head -10 || echo "No tracing pods found"
    exit 1
fi

# Wait for Tempo to be ready with robust checking
print_step "Waiting for Tempo to be ready..."
echo "Waiting for Tempo to be ready..."

# Dynamically find Tempo deployment name
TEMPO_DEPLOYMENT=$(kubectl get deployments -n tracing -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$TEMPO_DEPLOYMENT" ]; then
    echo "⚠️ Could not find Tempo deployment, checking for any Tempo-related deployment..."
    TEMPO_DEPLOYMENT=$(kubectl get deployments -n tracing -l app.kubernetes.io/component=tempo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi
if [ -z "$TEMPO_DEPLOYMENT" ]; then
    echo "⚠️ Still could not find Tempo deployment, proceeding anyway..."
else
    echo "Found Tempo deployment: $TEMPO_DEPLOYMENT"
    # Wait for pods to be running first
    echo "Waiting for Tempo pods to be running..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tempo -n tracing --timeout=300s 2>/dev/null || echo "⚠️ Timeout waiting for Tempo pods to be ready, continuing..."
    # Then wait for deployment to be available
    kubectl wait --for=condition=available deployment/$TEMPO_DEPLOYMENT -n tracing --timeout=300s || echo "⚠️ Timeout waiting for Tempo deployment, continuing anyway..."
fi

# Verify Tempo is working by checking logs
print_step "Verifying Tempo installation..."
echo "Checking Tempo logs for errors..."
TEMPO_POD=$(kubectl get pods -n tracing -l app.kubernetes.io/name=tempo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$TEMPO_POD" ]; then
    echo "Tempo pod: $TEMPO_POD"
    echo "Recent Tempo logs:"
    kubectl logs $TEMPO_POD -n tracing --tail=20 2>/dev/null || echo "Could not retrieve Tempo logs"
else
    echo "No Tempo pod found"
fi

# Step 5: Deploy ArgoCD for GitOps
print_step "Deploying ArgoCD for GitOps..."
echo "Deploying ArgoCD..."
if ! helm list -n argocd 2>/dev/null | grep -q argocd; then
    # Ensure ArgoCD repo is added
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Wait for namespace to be ready
    sleep 5
    
    # Deploy ArgoCD
    helm install argocd argo/argo-cd -n argocd --create-namespace --set server.service.type=LoadBalancer
    
    if [ $? -eq 0 ]; then
        print_success "ArgoCD deployed successfully"
    else
        print_error "Failed to deploy ArgoCD"
        exit 1
    fi
else
    echo "✅ ArgoCD already deployed, skipping"
fi

# Step 6: Apply ArgoCD Application manifests
print_step "Applying ArgoCD Application manifests..."
echo "Applying ArgoCD Application manifests..."
if [ -f "eks-infrastructure/argocd/argocd-app.yaml" ]; then
    kubectl apply -f eks-infrastructure/argocd/argocd-app.yaml
    if [ $? -eq 0 ]; then
        print_success "ArgoCD Application manifests applied successfully"
    else
        print_error "Failed to apply ArgoCD Application manifests"
        exit 1
    fi
else
    print_warning "ArgoCD Application manifest not found, skipping"
fi

# Final instructions
print_step "Checking overall deployment status..."
echo "Checking deployment status in all namespaces:"
echo "Monitoring namespace:"
kubectl get pods -n monitoring 2>/dev/null || echo "No monitoring namespace found"
echo ""
echo "Tracing namespace:"
kubectl get pods -n tracing 2>/dev/null || echo "No tracing namespace found"
echo ""
echo "ArgoCD namespace:"
kubectl get pods -n argocd 2>/dev/null || echo "No argocd namespace found"
echo ""

print_success "Setup Complete!"
echo ""
echo "💡 Tips:"
echo "- Use 'kubectl port-forward' for local development"
echo "- Check logs with 'kubectl logs -f deployment/app-name'"
echo "- Monitor with 'kubectl top pods' and Grafana dashboards"
echo "- Access ArgoCD UI with 'kubectl port-forward svc/argocd-server -n argocd 8080:443'"
echo "- Access Grafana with 'kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80'"
echo "- Access Tempo with 'kubectl port-forward svc/tempo -n tracing 3100:3100'"
echo ""
echo "📋 Next steps:"
echo "1. Configure your application to send traces to Tempo"
echo "2. Set up dashboards in Grafana for monitoring"
echo "3. Configure alerts in Prometheus AlertManager"
echo "4. Set up your GitOps workflow with ArgoCD"
