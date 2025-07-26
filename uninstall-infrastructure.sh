#!/bin/bash

# Comprehensive EKS Infrastructure Uninstall Script
# This script completely removes all resources created by setup-infrastructure.sh
# including Helm releases, PVCs, namespaces, and optionally the EKS cluster

set -e

# Configuration
CLUSTER_NAME="eks-otel-crud"
REGION="us-west-2"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}💡 $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for resource deletion
wait_for_deletion() {
    local resource_type=$1
    local namespace=$2
    local timeout=${3:-60}
    
    print_step "Waiting for $resource_type in namespace $namespace to be deleted..."
    
    local count=0
    while [ $count -lt $timeout ]; do
        if ! kubectl get $resource_type -n $namespace 2>/dev/null | grep -q "No resources found"; then
            sleep 2
            count=$((count + 2))
        else
            print_success "$resource_type in namespace $namespace deleted successfully"
            return 0
        fi
    done
    
    print_warning "Timeout waiting for $resource_type deletion in namespace $namespace"
    return 1
}

# Function to force delete stuck resources
force_delete_namespace() {
    local namespace=$1
    
    print_step "Force deleting namespace: $namespace"
    
    # Special handling for ArgoCD namespace - remove application finalizers first
    if [ "$namespace" = "argocd" ]; then
        print_step "Removing ArgoCD application finalizers..."
        # Remove finalizers from ArgoCD applications
        kubectl get applications -n $namespace --no-headers 2>/dev/null | awk '{print $1}' | \
            xargs -I {} kubectl patch application {} -n $namespace -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        
        # Remove finalizers from ArgoCD applicationsets
        kubectl get applicationsets -n $namespace --no-headers 2>/dev/null | awk '{print $1}' | \
            xargs -I {} kubectl patch applicationset {} -n $namespace -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        
        # Remove finalizers from ArgoCD appprojects
        kubectl get appprojects -n $namespace --no-headers 2>/dev/null | awk '{print $1}' | \
            xargs -I {} kubectl patch appproject {} -n $namespace -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        
        print_success "ArgoCD finalizers removed"
    fi
    
    # Remove finalizers from all resources in the namespace
    kubectl get all -n $namespace -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.finalizers != null) | "\(.kind)/\(.metadata.name)"' | \
        xargs -I {} kubectl patch {} -n $namespace -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    
    # Force delete the namespace
    kubectl delete namespace $namespace --force --grace-period=0 2>/dev/null || true
    
    # Remove namespace from etcd if it's stuck
    kubectl get namespace $namespace -o json 2>/dev/null | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/$namespace/finalize" -f - 2>/dev/null || true
}

echo "🗑️  EKS Infrastructure Uninstall Script"
echo "======================================"
echo ""

# Check prerequisites
print_step "Checking prerequisites..."
if ! command_exists kubectl; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! command_exists helm; then
    print_error "helm is not installed"
    exit 1
fi

if ! command_exists aws; then
    print_error "aws CLI is not installed"
    exit 1
fi

print_success "All prerequisites are available"

# Confirm destructive action
echo ""
print_warning "⚠️  WARNING: This will completely destroy all infrastructure!"
print_info "This includes:"
echo "  • All Helm releases (ArgoCD, Prometheus, Grafana, Tempo)"
echo "  • All PersistentVolumeClaims and data"
echo "  • All namespaces (monitoring, tracing, argocd)"
echo "  • Optionally: The entire EKS cluster"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    print_info "Uninstall cancelled"
    exit 0
fi

echo ""
print_step "Starting infrastructure cleanup..."

# Step 1: Uninstall Helm releases
print_step "Uninstalling Helm releases..."

# Uninstall Tempo
if helm list -n tracing 2>/dev/null | grep -q tempo; then
    print_step "Uninstalling Grafana Tempo..."
    helm uninstall tempo -n tracing --wait || print_warning "Failed to uninstall Tempo cleanly"
    print_success "Tempo uninstalled"
else
    print_info "Tempo not found, skipping"
fi

# Uninstall Prometheus/Grafana stack
if helm list -n monitoring 2>/dev/null | grep -q prometheus; then
    print_step "Uninstalling Prometheus/Grafana stack..."
    helm uninstall prometheus -n monitoring --wait || print_warning "Failed to uninstall Prometheus cleanly"
    print_success "Prometheus/Grafana stack uninstalled"
else
    print_info "Prometheus stack not found, skipping"
fi

# Uninstall ArgoCD
if helm list -n argocd 2>/dev/null | grep -q argocd; then
    print_step "Uninstalling ArgoCD..."
    helm uninstall argocd -n argocd --wait || print_warning "Failed to uninstall ArgoCD cleanly"
    print_success "ArgoCD uninstalled"
else
    print_info "ArgoCD not found, skipping"
fi

# Step 2: Delete PersistentVolumeClaims
print_step "Deleting PersistentVolumeClaims..."

namespaces=("monitoring" "tracing" "argocd")
for ns in "${namespaces[@]}"; do
    if kubectl get namespace $ns 2>/dev/null; then
        print_step "Deleting PVCs in namespace: $ns"
        kubectl delete pvc --all -n $ns --force --grace-period=0 2>/dev/null || true
        
        # Wait a moment for PVCs to be deleted
        sleep 5
        
        # Check if any PVCs are still there and force delete them
        remaining_pvcs=$(kubectl get pvc -n $ns --no-headers 2>/dev/null | wc -l)
        if [ $remaining_pvcs -gt 0 ]; then
            print_warning "Force deleting remaining PVCs in $ns"
            kubectl get pvc -n $ns -o name 2>/dev/null | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge -n $ns 2>/dev/null || true
            kubectl delete pvc --all -n $ns --force --grace-period=0 2>/dev/null || true
        fi
        
        print_success "PVCs deleted in namespace: $ns"
    fi
done

# Step 3: Delete PersistentVolumes
print_step "Deleting orphaned PersistentVolumes..."
kubectl get pv --no-headers 2>/dev/null | grep -E "(monitoring|tracing|argocd)" | awk '{print $1}' | xargs -I {} kubectl delete pv {} --force --grace-period=0 2>/dev/null || true
print_success "Orphaned PersistentVolumes cleaned up"

# Step 4: Force delete namespaces
print_step "Deleting namespaces..."

for ns in "${namespaces[@]}"; do
    if kubectl get namespace $ns 2>/dev/null; then
        print_step "Deleting namespace: $ns"
        
        # First try normal deletion
        kubectl delete namespace $ns --timeout=30s 2>/dev/null || {
            print_warning "Normal deletion failed for $ns, force deleting..."
            force_delete_namespace $ns
        }
        
        # Wait for namespace to be fully deleted
        timeout=60
        count=0
        while kubectl get namespace $ns 2>/dev/null && [ $count -lt $timeout ]; do
            sleep 2
            count=$((count + 2))
        done
        
        if kubectl get namespace $ns 2>/dev/null; then
            print_warning "Namespace $ns still exists after force deletion attempt"
        else
            print_success "Namespace $ns deleted successfully"
        fi
    else
        print_info "Namespace $ns not found, skipping"
    fi
done

# Step 5: Clean up any remaining resources
print_step "Cleaning up remaining resources..."

# Delete any remaining ConfigMaps, Secrets, or other resources that might be left
kubectl delete configmap --all-namespaces -l app.kubernetes.io/managed-by=Helm 2>/dev/null || true
kubectl delete secret --all-namespaces -l app.kubernetes.io/managed-by=Helm 2>/dev/null || true

# Clean up any CRDs that might have been created
print_step "Cleaning up Custom Resource Definitions..."
kubectl delete crd --all --timeout=30s 2>/dev/null || true

print_success "Resource cleanup completed"

# Step 6: Ask about EKS cluster deletion
echo ""
print_warning "Do you want to delete the EKS cluster as well?"
print_info "Cluster: $CLUSTER_NAME in region $REGION"
echo ""
read -p "Delete EKS cluster? (type 'yes' to confirm): " delete_cluster

if [ "$delete_cluster" = "yes" ]; then
    print_step "Deleting EKS cluster: $CLUSTER_NAME"
    print_warning "This will take 10-15 minutes..."
    
    # Delete the cluster
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION 2>/dev/null; then
        aws eks delete-cluster --name $CLUSTER_NAME --region $REGION
        
        # Wait for cluster deletion
        print_step "Waiting for cluster deletion to complete..."
        aws eks wait cluster-deleted --name $CLUSTER_NAME --region $REGION
        
        print_success "EKS cluster deleted successfully"
        
        # Clean up kubectl context
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        kubectl config delete-context "arn:aws:eks:$REGION:$ACCOUNT_ID:cluster/$CLUSTER_NAME" 2>/dev/null || true
        print_success "kubectl context cleaned up"
        
        # Clean up remaining CloudFormation stacks
        print_step "Cleaning up remaining CloudFormation stacks..."
        
        # Get all eksctl-related stacks for this cluster
        EKSCTL_STACKS=$(aws cloudformation list-stacks --region $REGION --query "StackSummaries[?contains(StackName, 'eksctl-$CLUSTER_NAME') && StackStatus != 'DELETE_COMPLETE'].StackName" --output text)
        
        if [ -n "$EKSCTL_STACKS" ]; then
            print_warning "Found remaining CloudFormation stacks, deleting them..."
            
            # Delete stacks in the correct order (addons and nodegroups first, then cluster)
            for stack in $EKSCTL_STACKS; do
                if [[ $stack == *"addon"* ]] || [[ $stack == *"nodegroup"* ]]; then
                    print_step "Deleting CloudFormation stack: $stack"
                    aws cloudformation delete-stack --stack-name $stack --region $REGION 2>/dev/null || true
                fi
            done
            
            # Wait a bit for addon/nodegroup deletions to start
            sleep 10
            
            # Delete cluster stack last
            for stack in $EKSCTL_STACKS; do
                if [[ $stack == *"cluster"* ]]; then
                    print_step "Deleting CloudFormation stack: $stack"
                    aws cloudformation delete-stack --stack-name $stack --region $REGION 2>/dev/null || true
                fi
            done
            
            # Wait for all stacks to be deleted
            print_step "Waiting for CloudFormation stacks to be deleted..."
            for stack in $EKSCTL_STACKS; do
                print_step "Waiting for stack deletion: $stack"
                aws cloudformation wait stack-delete-complete --stack-name $stack --region $REGION 2>/dev/null || {
                    print_warning "Stack $stack deletion timed out or failed, but continuing..."
                }
            done
            
            print_success "CloudFormation stacks cleanup completed"
        else
            print_success "No remaining CloudFormation stacks found"
        fi
    else
        print_info "EKS cluster $CLUSTER_NAME not found"
    fi
else
    print_info "EKS cluster preserved"
fi

# Step 7: Clean up Helm repositories (optional)
echo ""
read -p "Remove Helm repositories? (y/n): " remove_repos

if [ "$remove_repos" = "y" ] || [ "$remove_repos" = "yes" ]; then
    print_step "Removing Helm repositories..."
    helm repo remove prometheus-community 2>/dev/null || true
    helm repo remove grafana 2>/dev/null || true
    helm repo remove argo 2>/dev/null || true
    print_success "Helm repositories removed"
fi

# Final summary
echo ""
print_success "🎉 Infrastructure cleanup completed!"
echo ""
print_info "Summary of actions taken:"
echo "  ✅ Uninstalled all Helm releases"
echo "  ✅ Deleted all PersistentVolumeClaims"
echo "  ✅ Deleted all PersistentVolumes"
echo "  ✅ Deleted all namespaces (monitoring, tracing, argocd)"
echo "  ✅ Cleaned up Custom Resource Definitions"

if [ "$delete_cluster" = "yes" ]; then
    echo "  ✅ Deleted EKS cluster: $CLUSTER_NAME"
    echo "  ✅ Cleaned up kubectl context"
fi

if [ "$remove_repos" = "y" ] || [ "$remove_repos" = "yes" ]; then
    echo "  ✅ Removed Helm repositories"
fi

echo ""
print_info "Your AWS account is now clean of the EKS infrastructure resources."

if [ "$delete_cluster" != "yes" ]; then
    echo ""
    print_warning "Note: EKS cluster '$CLUSTER_NAME' is still running and incurring costs."
    print_info "To delete it later, run: aws eks delete-cluster --name $CLUSTER_NAME --region $REGION"
fi

echo ""
print_success "Uninstall script completed successfully! 🗑️"
