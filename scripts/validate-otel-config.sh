#!/bin/bash

# OpenTelemetry Collector Configuration Validation Script
# Validates the enhanced OTEL Collector configuration before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration file path
OTEL_CONFIG_FILE="eks-infrastructure/monitoring/otel-collector-values.yaml"
BACKUP_CONFIG_FILE="eks-infrastructure/monitoring/otel-collector-values.yaml.backup"

echo "🧪 OpenTelemetry Collector Configuration Validation"
echo "=================================================="

# Step 1: Check if configuration files exist
print_step "Checking configuration files..."
if [ ! -f "$OTEL_CONFIG_FILE" ]; then
    print_error "OpenTelemetry Collector configuration file not found: $OTEL_CONFIG_FILE"
    exit 1
fi

if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
    print_warning "Backup configuration file not found: $BACKUP_CONFIG_FILE"
else
    print_success "Backup configuration file found"
fi

print_success "Configuration files found"

# Step 2: Validate YAML syntax
print_step "Validating YAML syntax..."
if command -v yq &> /dev/null; then
    if yq eval '.' "$OTEL_CONFIG_FILE" > /dev/null 2>&1; then
        print_success "YAML syntax is valid"
    else
        print_error "YAML syntax validation failed"
        exit 1
    fi
else
    print_warning "yq not found, skipping YAML syntax validation"
fi

# Step 3: Check required services are available
print_step "Checking required services availability..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not available. Please install kubectl to continue."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot access Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_success "Kubernetes cluster is accessible"

# Step 4: Check if required namespaces exist
print_step "Checking required namespaces..."

REQUIRED_NAMESPACES=("monitoring" "logging" "tracing")
for namespace in "${REQUIRED_NAMESPACES[@]}"; do
    if kubectl get namespace "$namespace" &> /dev/null; then
        print_success "Namespace '$namespace' exists"
    else
        print_error "Required namespace '$namespace' does not exist"
        echo "Please create the namespace: kubectl create namespace $namespace"
        exit 1
    fi
done

# Step 5: Check if target services are running
print_step "Checking target services..."

# Check Tempo
if kubectl get service tempo -n tracing &> /dev/null; then
    print_success "Tempo service found in tracing namespace"
else
    print_warning "Tempo service not found. Traces export may fail."
fi

# Check Loki
if kubectl get service loki-gateway -n logging &> /dev/null; then
    print_success "Loki gateway service found in logging namespace"
else
    print_warning "Loki gateway service not found. Logs export may fail."
fi

# Check Prometheus
PROMETHEUS_SERVICE=$(kubectl get service -n monitoring -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)
if [ -n "$PROMETHEUS_SERVICE" ]; then
    print_success "Prometheus service found in monitoring namespace"
else
    print_warning "Prometheus service not found. Metrics export may fail."
fi

# Step 6: Validate configuration structure
print_step "Validating configuration structure..."

# Check if all required sections exist
REQUIRED_SECTIONS=("receivers" "processors" "exporters" "service")
for section in "${REQUIRED_SECTIONS[@]}"; do
    if yq eval ".config.$section" "$OTEL_CONFIG_FILE" | grep -q "null"; then
        print_error "Required section '$section' is missing or null"
        exit 1
    else
        print_success "Section '$section' found"
    fi
done

# Step 7: Check pipeline configuration
print_step "Validating pipeline configuration..."

# Check if all three pipelines exist
REQUIRED_PIPELINES=("traces" "metrics" "logs")
for pipeline in "${REQUIRED_PIPELINES[@]}"; do
    if yq eval ".config.service.pipelines.$pipeline" "$OTEL_CONFIG_FILE" | grep -q "null"; then
        print_error "Required pipeline '$pipeline' is missing or null"
        exit 1
    else
        print_success "Pipeline '$pipeline' configured"
    fi
done

# Step 8: Check resource limits
print_step "Validating resource configuration..."

CPU_LIMIT=$(yq eval '.resources.limits.cpu' "$OTEL_CONFIG_FILE")
MEMORY_LIMIT=$(yq eval '.resources.limits.memory' "$OTEL_CONFIG_FILE")

if [ "$CPU_LIMIT" != "null" ] && [ "$MEMORY_LIMIT" != "null" ]; then
    print_success "Resource limits configured: CPU=$CPU_LIMIT, Memory=$MEMORY_LIMIT"
else
    print_warning "Resource limits not properly configured"
fi

# Step 9: Check RBAC configuration
print_step "Validating RBAC configuration..."

SERVICE_ACCOUNT=$(yq eval '.serviceAccount.create' "$OTEL_CONFIG_FILE")
CLUSTER_ROLE=$(yq eval '.clusterRole.create' "$OTEL_CONFIG_FILE")

if [ "$SERVICE_ACCOUNT" == "true" ] && [ "$CLUSTER_ROLE" == "true" ]; then
    print_success "RBAC configuration is properly set"
else
    print_warning "RBAC configuration may be incomplete"
fi

# Step 10: Generate deployment preview
print_step "Generating deployment preview..."

echo ""
echo "📋 Configuration Summary:"
echo "========================"
echo "• Deployment mode: $(yq eval '.mode' "$OTEL_CONFIG_FILE")"
echo "• Replica count: $(yq eval '.replicaCount' "$OTEL_CONFIG_FILE")"
echo "• CPU limit: $(yq eval '.resources.limits.cpu' "$OTEL_CONFIG_FILE")"
echo "• Memory limit: $(yq eval '.resources.limits.memory' "$OTEL_CONFIG_FILE")"
echo "• Pipelines configured: traces, metrics, logs"
echo "• Target services:"
echo "  - Traces → Tempo (tracing namespace)"
echo "  - Logs → Loki (logging namespace)"  
echo "  - Metrics → Prometheus (monitoring namespace)"

echo ""
print_success "Configuration validation completed successfully!"
echo ""
echo "🚀 Next steps:"
echo "1. Review the configuration summary above"
echo "2. If everything looks correct, deploy with: helm upgrade otel-collector ..."
echo "3. Monitor the deployment with: kubectl logs -f deployment/otel-collector -n tracing"
echo "4. Test each pipeline (traces, metrics, logs) after deployment"
echo ""
echo "💡 Rollback command (if needed):"
echo "cp $BACKUP_CONFIG_FILE $OTEL_CONFIG_FILE"
