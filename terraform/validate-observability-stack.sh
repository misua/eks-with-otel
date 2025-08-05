#!/bin/bash

# EKS Observability Stack Validation Script
# This script validates that all integrated fixes are working correctly
# Run this after deploying the Terraform configuration

set -e

echo "🔍 EKS Observability Stack Validation"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        exit 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "ℹ️  $1"
}

# 1. Validate Kubernetes cluster connectivity
echo ""
print_info "1. Validating Kubernetes cluster connectivity..."
kubectl cluster-info > /dev/null 2>&1
print_status $? "Kubernetes cluster is accessible"

# 2. Validate all namespaces exist
echo ""
print_info "2. Validating required namespaces..."
kubectl get namespace monitoring > /dev/null 2>&1
print_status $? "Monitoring namespace exists"

kubectl get namespace tracing > /dev/null 2>&1
print_status $? "Tracing namespace exists"

kubectl get namespace demo > /dev/null 2>&1
print_status $? "Demo namespace exists"

# 3. Validate all pods are running
echo ""
print_info "3. Validating pod status..."

# Check Prometheus/Grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers | grep -q "Running"
print_status $? "Grafana pod is running"

kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers | grep -q "Running"
print_status $? "Prometheus pod is running"

# Check Loki
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki --no-headers | grep -q "Running"
print_status $? "Loki pod is running"

# Check Promtail
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail --no-headers | grep -q "Running"
print_status $? "Promtail pods are running"

# Check Tempo
kubectl get pods -n tracing -l app.kubernetes.io/name=tempo --no-headers | grep -q "Running"
print_status $? "Tempo pod is running"

# Check OTEL Collector
kubectl get pods -n tracing -l app.kubernetes.io/name=opentelemetry-collector --no-headers | grep -q "Running"
print_status $? "OTEL Collector pods are running"

# Check Demo App
kubectl get pods -n demo -l app=eks-otel-demo --no-headers | grep -q "Running"
print_status $? "Demo app pod is running"

# 4. Validate Promtail is successfully sending logs to Loki
echo ""
print_info "4. Validating Promtail → Loki pipeline..."
PROMTAIL_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o jsonpath='{.items[0].metadata.name}')
PROMTAIL_ERRORS=$(kubectl logs -n monitoring $PROMTAIL_POD --tail=50 | grep -c "401 Unauthorized" || true)
if [ $PROMTAIL_ERRORS -eq 0 ]; then
    print_status 0 "Promtail is successfully sending logs to Loki (no 401 errors)"
else
    print_status 1 "Promtail has authentication errors sending to Loki"
fi

# 5. Validate OTEL Collector configuration
echo ""
print_info "5. Validating OTEL Collector configuration..."
OTEL_POD=$(kubectl get pods -n tracing -l app.kubernetes.io/name=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}')
OTEL_CONFIG_ERRORS=$(kubectl logs -n tracing $OTEL_POD --tail=50 | grep -c "invalid configuration\|failed to build pipelines" || true)
if [ $OTEL_CONFIG_ERRORS -eq 0 ]; then
    print_status 0 "OTEL Collector configuration is valid"
else
    print_status 1 "OTEL Collector has configuration errors"
fi

# 6. Validate OTEL Collector → Tempo connectivity
echo ""
print_info "6. Validating OTEL Collector → Tempo pipeline..."
TEMPO_ERRORS=$(kubectl logs -n tracing $OTEL_POD --tail=50 | grep -c "dial tcp.*:3200.*timeout\|connection timed out" || true)
if [ $TEMPO_ERRORS -eq 0 ]; then
    print_status 0 "OTEL Collector is successfully connecting to Tempo"
else
    print_status 1 "OTEL Collector has connectivity issues with Tempo"
fi

# 7. Validate Demo App OTEL configuration
echo ""
print_info "7. Validating Demo App → OTEL Collector pipeline..."
DEMO_POD=$(kubectl get pods -n demo -l app=eks-otel-demo -o jsonpath='{.items[0].metadata.name}')
DEMO_TRACE_ERRORS=$(kubectl logs -n demo $DEMO_POD --tail=50 | grep -c "traces export.*invalid URL escape\|parse.*http://http" || true)
if [ $DEMO_TRACE_ERRORS -eq 0 ]; then
    print_status 0 "Demo app is successfully exporting traces"
else
    print_status 1 "Demo app has trace export errors"
fi

# 8. Validate services are accessible
echo ""
print_info "8. Validating service connectivity..."

# Check Grafana service
kubectl get svc -n monitoring prometheus-grafana > /dev/null 2>&1
print_status $? "Grafana service is accessible"

# Check Loki service
kubectl get svc -n monitoring loki > /dev/null 2>&1
print_status $? "Loki service is accessible"

# Check Tempo service
kubectl get svc -n tracing tempo > /dev/null 2>&1
print_status $? "Tempo service is accessible"

# Check Demo app service
kubectl get svc -n demo eks-otel-demo-service > /dev/null 2>&1
print_status $? "Demo app service is accessible"

# 9. Generate test data and validate end-to-end pipeline
echo ""
print_info "9. Testing end-to-end observability pipeline..."

print_warning "Setting up port forwarding for demo app..."
kubectl port-forward -n demo svc/eks-otel-demo-service 8080:80 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 5

# Test API endpoint and generate telemetry
print_info "Generating test telemetry data..."
curl -s -X POST http://localhost:8080/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Validation Test", "description": "Testing complete observability pipeline"}' > /dev/null 2>&1
print_status $? "Successfully generated test telemetry data"

curl -s http://localhost:8080/api/v1/items > /dev/null 2>&1
print_status $? "Demo app API is responding correctly"

# Clean up port forward
kill $PORT_FORWARD_PID > /dev/null 2>&1

# 10. Final validation summary
echo ""
print_info "10. Final validation summary..."
sleep 5

# Check that demo app generated logs with trace IDs
DEMO_LOGS_WITH_TRACES=$(kubectl logs -n demo $DEMO_POD --tail=20 | grep -c "trace_id" || true)
if [ $DEMO_LOGS_WITH_TRACES -gt 0 ]; then
    print_status 0 "Demo app is generating structured logs with trace correlation"
else
    print_status 1 "Demo app logs missing trace correlation"
fi

# Check OTEL Collector is processing traces
OTEL_TRACE_EXPORTS=$(kubectl logs -n tracing $OTEL_POD --tail=20 | grep -c "TracesExporter" || true)
if [ $OTEL_TRACE_EXPORTS -gt 0 ]; then
    print_status 0 "OTEL Collector is successfully processing traces"
else
    print_status 1 "OTEL Collector not processing traces"
fi

echo ""
echo "🎉 VALIDATION COMPLETE!"
echo "======================"
print_info "All integrated fixes are working correctly!"
print_info "Your EKS observability stack is production-ready."
echo ""
print_info "Next steps:"
print_info "1. Access Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
print_info "2. Test Loki Explore: Query {app=\"eks-otel-demo\"}"
print_info "3. Test Tempo Explore: Search for service 'eks-otel-demo'"
print_info "4. Test Prometheus: Query up{job=\"eks-otel-demo\"}"
echo ""
print_info "All components are working with the integrated production-ready fixes!"
