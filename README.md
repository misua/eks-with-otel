# EKS with OpenTelemetry Observability Stack

A complete, production-ready observability solution for Amazon EKS with OpenTelemetry, featuring distributed tracing, structured logging, metrics collection, and a demo Go CRUD application.

## 📊 Current Implementation Status

### ✅ **Completed & Ready to Deploy**
- **📈 Prometheus** - Metrics collection and storage with persistent volumes
- **📊 Grafana** - Unified visualization dashboard with persistence enabled
- **📝 Loki** - Log aggregation system with SimpleScalable architecture
- **📄 Promtail** - Log collection DaemonSet for Kubernetes logs
- **🔍 Tempo** - Distributed tracing storage backend
- **🔧 Enhanced OpenTelemetry Collector** - Multi-signal telemetry processing (traces, metrics, logs)
- **🚀 Demo Go CRUD Application** - Fully instrumented with OpenTelemetry tracing and structured logging
- **📊 Automated Load Generator** - Continuously generates realistic observability data
- **🛠️ Deployment Automation** - Complete infrastructure setup scripts
- **📚 Comprehensive Documentation** - Step-by-step guides and troubleshooting

### 🚧 **Planned Future Enhancements (TODO)**
- 🔄 **Argo Rollouts** - Advanced deployment strategies (blue-green, canary) for zero-downtime releases
- 🛡️ **Kyverno** - Policy-as-code engine for Kubernetes security and governance automation
- 🔍 **Trivy** - Comprehensive vulnerability scanner for containers, IaC, and Kubernetes manifests
- 📢 **Slack Alerts** - Real-time notifications for monitoring alerts, deployment status, and security events
- 🚨 **Falco** - Runtime security monitoring for detecting anomalous behavior and security threats
- 📝 **Enhanced Loki** - Advanced log parsing, retention policies, and multi-tenant configuration
- 🔔 **AlertManager** - Advanced alerting rules, routing, and notification management
- ⚡ **Karpenter** - Intelligent node provisioning and autoscaling for cost-optimized workload scheduling

## 🏗️ Architecture Overview

```mermaid
flowchart TB
    subgraph "GitOps & Deployment"
        Git["Git Repository<br/>📁 Helm Charts & Configs"]
        ArgoCD["ArgoCD<br/>🔄 GitOps Controller"]
        Git --> ArgoCD
    end

    subgraph "EKS Cluster"
        subgraph "Applications"
            DemoApp["Demo CRUD App<br/>🚀 Go Application"]
            LoadGen["Load Generator<br/>📊 Traffic Simulator"]
        end
        
        subgraph "OpenTelemetry Collection"
            OTELCol["OTEL Collector<br/>🔧 Multi-Signal Processor"]
        end
        
        subgraph "Log Collection"
            Promtail["Promtail<br/>📝 Log Shipper"]
            K8sLogs["Kubernetes Logs<br/>📋 Node & Pod Logs"]
        end
        
        subgraph "Observability Stack"
            subgraph "Storage Backends"
                Prometheus["Prometheus<br/>📈 Metrics Storage"]
                Loki["Loki<br/>📄 Log Storage"]
                Tempo["Tempo<br/>🔍 Trace Storage"]
            end
            
            subgraph "Visualization"
                Grafana["Grafana<br/>📊 Unified Dashboard"]
            end
        end
    end

    %% Data Flow: Applications to OTEL Collector
    DemoApp -->|"OTLP HTTP/gRPC<br/>Traces + Metrics + Logs"| OTELCol
    LoadGen -->|"OTLP HTTP/gRPC<br/>Traces + Metrics + Logs"| OTELCol
    
    %% Data Flow: Kubernetes Logs
    K8sLogs -->|"Log Files<br/>/var/log/pods"| Promtail
    Promtail -->|"Push API<br/>Structured Logs"| Loki
    
    %% Data Flow: OTEL Collector to Backends
    OTELCol -->|"Remote Write<br/>Application Metrics"| Prometheus
    OTELCol -->|"Push API<br/>Structured Logs"| Loki
    OTELCol -->|"OTLP<br/>Distributed Traces"| Tempo
    
    %% Data Flow: Backends to Grafana
    Prometheus -->|"PromQL Queries<br/>Metrics Data"| Grafana
    Loki -->|"LogQL Queries<br/>Log Data"| Grafana
    Tempo -->|"TraceQL Queries<br/>Trace Data"| Grafana
    
    %% GitOps Flow
    ArgoCD -->|"Helm Deployments"| Prometheus
    ArgoCD -->|"Helm Deployments"| Loki
    ArgoCD -->|"Helm Deployments"| Tempo
    ArgoCD -->|"Helm Deployments"| Grafana
    ArgoCD -->|"Helm Deployments"| OTELCol
    ArgoCD -->|"Helm Deployments"| Promtail
    ArgoCD -->|"Kubectl Apply"| DemoApp
    ArgoCD -->|"Kubectl Apply"| LoadGen

    %% Styling
    classDef appStyle fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef otelStyle fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef storageStyle fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef gitopsStyle fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef logStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    
    class DemoApp,LoadGen appStyle
    class OTELCol otelStyle
    class Prometheus,Loki,Tempo,Grafana storageStyle
    class Git,ArgoCD gitopsStyle
    class Promtail,K8sLogs logStyle
```

### 🔄 Data Flow Explanation

1. **Application Telemetry**: Demo app and load generator send traces, metrics, and logs via OTLP to the OpenTelemetry Collector
2. **Kubernetes Logs**: Promtail DaemonSet collects logs from all pods and nodes, forwarding them to Loki
3. **Signal Processing**: OTEL Collector processes, enriches, and routes telemetry data to appropriate backends
4. **Storage**: Prometheus stores metrics, Loki stores logs, Tempo stores traces
5. **Visualization**: Grafana queries all backends to provide unified dashboards with correlated observability data
6. **GitOps**: ArgoCD monitors Git repository and automatically deploys/updates all infrastructure components

### 🎯 Key Integration Points

- **Trace Correlation**: Logs include trace IDs for seamless correlation in Grafana
- **Kubernetes Metadata**: OTEL Collector enriches all telemetry with pod, namespace, and node information
- **Unified Querying**: Single Grafana interface for metrics (PromQL), logs (LogQL), and traces (TraceQL)
- **Automated Deployment**: ArgoCD ensures infrastructure and applications stay in sync with Git repository

## 🚀 Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Terraform >= 1.0 installed
- Helm 3.x installed
- Docker installed
- Go 1.21+ installed

---

# 📋 Deployment Options

This project supports two deployment methods:

1. **🏗️ Terraform Deployment** (Recommended) - Infrastructure as Code with full automation
2. **📜 Script-based Deployment** - Traditional Helm/kubectl approach

---

# 🏗️ Terraform Deployment (Recommended)

## Overview

The Terraform deployment provides a complete, production-ready EKS observability stack with:

- **EKS Cluster** with managed node groups
- **Complete Observability Stack** (Prometheus, Grafana, Loki, Tempo, Enhanced OTEL Collector)
- **Networking** (VPC, subnets, security groups)
- **Storage** (EBS CSI driver, persistent volumes)
- **GitOps** (ArgoCD for application management)

## Phase 1: Infrastructure Setup

### Step 1: Prepare Terraform Environment
```bash
# Clone the repository
git clone <your-repo-url>
cd eks-with-otel/terraform

# Initialize Terraform
terraform init

# Review and customize variables (optional)
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Edit as needed
```

### Step 2: Deploy Complete Infrastructure
```bash
# Plan the deployment (review changes)
terraform plan

# Deploy the complete stack (takes 15-20 minutes)
terraform apply

# When prompted, type 'yes' to confirm
```

**What gets deployed:**
- ✅ **EKS Cluster** (`eks-otel-crud-dev`) with managed node groups
- ✅ **VPC & Networking** (private/public subnets, NAT gateways, security groups)
- ✅ **Prometheus + Grafana** (metrics collection and visualization)
- ✅ **Loki (SingleBinary)** (log aggregation with filesystem storage)
- ✅ **Promtail DaemonSet** (log collection from all pods/nodes)
- ✅ **Tempo** (distributed tracing storage)
- ✅ **Enhanced OpenTelemetry Collector** (multi-signal processing: traces, logs, metrics)
- ✅ **ArgoCD** (GitOps deployment platform)
- ✅ **EBS CSI Driver** (persistent storage support)
- ✅ **Proper RBAC** (service accounts, cluster roles, permissions)

### Step 3: Configure kubectl Access
```bash
# Update kubeconfig to access the new cluster
aws eks update-kubeconfig --region us-west-2 --name eks-otel-crud-dev

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

### Step 4: Verify Deployment Status
```bash
# Check all pods are running (may take 5-10 minutes for all to be ready)
kubectl get pods --all-namespaces

# Check specific observability namespaces
echo "=== MONITORING NAMESPACE ==="
kubectl get pods -n monitoring

echo "=== TRACING NAMESPACE ==="
kubectl get pods -n tracing

echo "=== ARGOCD NAMESPACE ==="
kubectl get pods -n argocd

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod --all -n tracing --timeout=300s
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
```

### Step 5: Access Grafana Dashboard
```bash
# Get Grafana admin password
echo "Grafana Admin Password:"
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
echo

# Port forward to access Grafana (run in separate terminal)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser: http://localhost:3000
# Username: admin
# Password: (from command above)
```

**Verify in Grafana:**
- ✅ **Data Sources**: Prometheus, Loki, Tempo should all be connected and healthy
- ✅ **Dashboards**: Default Kubernetes and infrastructure dashboards available
- ✅ **Explore**: Query each data source (metrics, logs, traces)

### Step 6: Verify Enhanced OpenTelemetry Collector
```bash
# Check OTEL Collector status
kubectl get pods -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# View OTEL Collector logs (should show multi-signal processing)
kubectl logs -n tracing deployment/otel-collector-opentelemetry-collector --tail=20

# Check OTEL Collector configuration
kubectl get configmap -n tracing otel-collector-opentelemetry-collector -o yaml
```

**Expected OTEL Collector Features:**
- ✅ **Multi-signal processing**: Traces, logs, and metrics
- ✅ **Kubernetes integration**: Pod/namespace metadata enrichment
- ✅ **Multiple receivers**: OTLP, Jaeger, Prometheus, host metrics
- ✅ **Smart routing**: Traces→Tempo, Logs→Loki, Metrics→Prometheus
- ✅ **Resource detection**: Automatic environment metadata

## Terraform Configuration Details

### Key Configuration Files
- **`main.tf`** - Main infrastructure definition (EKS, VPC, Helm releases)
- **`variables.tf`** - Configurable parameters (regions, instance types, chart versions)
- **`versions.tf`** - Provider version constraints
- **`terraform.tfvars`** - Your custom variable values

### Enhanced Configurations Used
- **`../eks-infrastructure/monitoring/loki-values.yaml`** - Loki SingleBinary configuration
- **`../eks-infrastructure/monitoring/promtail-values.yaml`** - Log collection DaemonSet
- **`../eks-infrastructure/monitoring/otel-collector-values.yaml`** - Enhanced multi-signal OTEL Collector

### Customization Options
```bash
# Edit variables before deployment
vim terraform/variables.tf

# Key customizable settings:
# - aws_region (default: us-west-2)
# - cluster_name (default: eks-otel-crud)
# - kubernetes_version (default: 1.28)
# - node_instance_types (default: t3.medium)
# - grafana_admin_password (default: admin123)
```

### Troubleshooting Common Issues

**Issue: Loki deployment fails with "Cannot run Scalable targets without object storage"**
```bash
# Solution: Ensure Loki is configured for SingleBinary mode
# Check: eks-infrastructure/monitoring/loki-values.yaml
# Should have: deploymentMode: SingleBinary
```

**Issue: Promtail pods in CrashLoopBackOff with volume mount errors**
```bash
# Solution: Remove duplicate Docker volume mounts
# Modern Kubernetes uses containerd, not Docker
# Check promtail-values.yaml for duplicate /var/lib/docker/containers mounts
```

**Issue: OTEL Collector fails with schema validation errors**
```bash
# Solution: Remove incompatible Helm chart properties
# Remove: clusterRoleBinding, service.ports from values file
# Use chart defaults for service configuration
```

**Issue: Terraform timeout during Helm releases**
```bash
# Solution: Increase timeout or apply in stages
terraform apply -target=module.eks
terraform apply -target=helm_release.prometheus
terraform apply  # Apply remaining resources
```

---

# 🚀 Demo Application Deployment

After successfully deploying the infrastructure with Terraform, you can deploy the Go demo CRUD application to generate telemetry data (logs, metrics, and traces).

## Deploy Demo Application via Terraform

The demo application will be automatically deployed as part of the Terraform infrastructure. It includes:

- **Go CRUD API** with OpenTelemetry instrumentation
- **Load Generator** for continuous traffic
- **Multi-signal telemetry** (logs, metrics, traces)
- **Automatic service discovery** and monitoring

### Step 7: Deploy Demo Application (Terraform)

```bash
# Enable demo application deployment
cd terraform
vim terraform.tfvars  # Add: deploy_demo_app = true

# Apply Terraform to deploy demo app
terraform apply
```

**What gets deployed:**
- ✅ **Go CRUD API** with OpenTelemetry instrumentation
- ✅ **Load Generator** for continuous traffic generation
- ✅ **ECR Repository** for container images
- ✅ **Kubernetes Deployments** with proper resource limits
- ✅ **Service Discovery** and monitoring integration

### Step 8: Verify Demo Application
```bash
# Check demo app pods
kubectl get pods -l app=eks-otel-demo

# Check load generator pods
kubectl get pods -l app=eks-otel-loadgen

# View application logs
kubectl logs -l app=eks-otel-demo --tail=20

# View load generator logs
kubectl logs -l app=eks-otel-loadgen --tail=20
```

### Step 9: Test Demo Application
```bash
# Port forward to access the demo app
kubectl port-forward service/eks-otel-demo-service 8080:80

# In another terminal, test the endpoints:
# Health check
curl http://localhost:8080/health

# Create an item
curl -X POST http://localhost:8080/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "Testing observability"}'

# List all items
curl http://localhost:8080/api/v1/items
```

### Step 10: Validate Multi-Signal Observability in Grafana

**Access Grafana:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open: http://localhost:3000 (admin/admin123)
```

**Validate Data Sources:**
- ✅ **Loki**: Query `{app="eks-otel-demo"}` to see application logs
- ✅ **Tempo**: Search service `eks-otel-demo` to see distributed traces  
- ✅ **Prometheus**: Query `http_requests_total{job="eks-otel-demo"}` for metrics

**Verify Trace/Log Correlation:**
- Logs contain `trace_id` fields that link directly to traces in Tempo
- Complete observability pipeline: **Logs** ↔ **Traces** ↔ **Metrics**

---

# 📊 What You'll See in Grafana

## Structured Logs (Loki)
```json
{
  "timestamp": "2025-01-27T11:00:39Z",
  "level": "info",
  "message": "HTTP request completed successfully",
  "method": "POST",
  "path": "/api/v1/items",
  "status_code": 201,
  "latency": "2.1ms",
  "client_ip": "10.0.1.45",
  "trace_id": "abc123def456...",
  "span_id": "789xyz012..."
}
```

## Distributed Traces (Tempo)
- **HTTP Request Spans**: Complete request lifecycle
- **Storage Operation Spans**: CRUD operations with item metadata
- **Business Logic Spans**: Application-specific operations
- **Error Spans**: Failed operations with error details
- **Span Attributes**: Item IDs, names, counts, and contextual data

## Metrics (Prometheus)
- **HTTP Metrics**: Request rates, response times, status codes
- **Application Metrics**: Business logic performance
- **Infrastructure Metrics**: Pod CPU, memory, network usage
- **Custom Metrics**: Application-specific measurements

## Trace/Log Correlation
- **Click trace_id in logs** → Jump directly to the trace in Tempo
- **Click span in trace** → See all related log entries in Loki
- **Full context switching** between logs, traces, and metrics
- **Unified troubleshooting** experience across all observability signals

---
# 🔧 Useful Commands

## Monitoring Commands
```bash
# Check all observability stack components
kubectl get pods -n monitoring -n tracing -n logging

# Restart a component if needed
kubectl rollout restart deployment/grafana -n monitoring

# Check OpenTelemetry Collector status
kubectl logs -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# Check Promtail log collection
kubectl logs -n logging -l app.kubernetes.io/name=promtail
```

## Demo App Commands
```bash
# Scale demo app
kubectl scale deployment eks-otel-demo --replicas=3

# Update demo app image
kubectl set image deployment/eks-otel-demo demo-app=$REGISTRY/eks-otel-demo:v2

# Check demo app service
kubectl describe service eks-otel-demo-service

# Port forward for local access
kubectl port-forward service/eks-otel-demo-service 8080:80
```

## Load Generator Commands
```bash
# Scale load generator
kubectl scale deployment eks-otel-loadgen --replicas=2

# Stop load generator
kubectl scale deployment eks-otel-loadgen --replicas=0

# Restart load generator
kubectl rollout restart deployment eks-otel-loadgen

# Check load generator configuration
kubectl describe deployment eks-otel-loadgen
```

## Grafana Access
```bash
# Get Grafana password
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port forward Grafana
kubectl port-forward --namespace monitoring svc/grafana 3000:80

# Access: http://localhost:3000 (admin / password-from-above)
```

---

# 🎯 Success Criteria

Your deployment is successful when:

- ✅ **All pods are running** in monitoring, tracing, and logging namespaces
- ✅ **Grafana is accessible** with all data sources connected (Prometheus, Loki, Tempo)
- ✅ **Demo app responds** to health checks and CRUD operations
- ✅ **Load generator is running** and generating continuous traffic
- ✅ **Logs appear in Loki** with structured JSON format and trace correlation
- ✅ **Traces appear in Tempo** showing distributed request flows
- ✅ **Metrics appear in Prometheus** showing HTTP and application metrics
- ✅ **Trace/log correlation works** - you can navigate between logs and traces using trace_id

## Troubleshooting

If something isn't working:

1. **Check pod status**: `kubectl get pods --all-namespaces`
2. **Check logs**: `kubectl logs <pod-name> -n <namespace>`
3. **Check services**: `kubectl get svc --all-namespaces`
4. **Verify data sources** in Grafana Explore section
5. **Check OpenTelemetry Collector** logs for trace/log processing issues

---

# 🚀 Next Steps

Once your observability stack is running:

1. **Create custom Grafana dashboards** for your specific use cases
2. **Set up alerting rules** in Prometheus for proactive monitoring
3. **Add more applications** to the cluster with OpenTelemetry instrumentation
4. **Explore advanced features** like trace sampling, log parsing, and metric aggregation
5. **Implement GitOps workflows** using ArgoCD for application deployments

You now have a complete, production-ready observability stack for your EKS cluster! 🎉

### Monitoring and Observability

The collector monitors itself and exports metrics about:
- Data processing rates and latencies
- Memory and CPU usage
- Queue sizes and backpressure
- Export success/failure rates
- Pipeline health status

### Validation and Testing

Use the validation script to test configuration before deployment:

```bash
# Validate enhanced configuration
./scripts/validate-otel-config.sh

# Deploy enhanced collector
helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  -n tracing \
  -f eks-infrastructure/monitoring/otel-collector-values.yaml

# Monitor deployment
kubectl logs -f deployment/otel-collector -n tracing
```

### Rollback Procedure

If issues occur with the enhanced configuration:

```bash
# Restore backup configuration
cp eks-infrastructure/monitoring/otel-collector-values.yaml.backup \
   eks-infrastructure/monitoring/otel-collector-values.yaml

# Redeploy with original configuration
helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  -n tracing \
  -f eks-infrastructure/monitoring/otel-collector-values.yaml
```

## 📋 Prerequisites Check

```bash
# Check if all tools are installed
./setup-infrastructure.sh
```

## 🏗️ Infrastructure Setup (Copy & Paste in Order)

### Step 1: Create EKS Cluster
```bash
# Create the EKS cluster (15-20 minutes)
eksctl create cluster -f eks-infrastructure/eks-cluster.yaml

# Verify cluster creation
kubectl get nodes
```

### Step 2: Configure kubectl
```bash
# Update kubeconfig for new cluster
aws eks update-kubeconfig --region us-west-2 --name eks-otel-crud

# Verify access
kubectl get svc
```

### Step 3: Install Helm Repositories
```bash
# Add required Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Step 4: Deploy Monitoring Stack
```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values eks-infrastructure/monitoring/prometheus-values.yaml

# Wait for deployment
kubectl wait --for=condition=available deployment/prometheus-kube-prometheus-stack-prometheus -n monitoring --timeout=300s
```

### Step 5: Deploy ArgoCD
```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

### Step 6: Get Access URLs
```bash
# Get ArgoCD URL
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ArgoCD: https://$ARGOCD_URL"

# Get Grafana URL
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana: https://$GRAFANA_URL"

# Get ArgoCD password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"
```

### Step 7: Configure ArgoCD
```bash
# Apply ArgoCD application
kubectl apply -f eks-infrastructure/argocd/argocd-app.yaml
```

### Step 8: Validate
```bash
# Check all components
kubectl get nodes
kubectl get pods -n monitoring
kubectl get pods -n argocd
```

## 📊 Default Credentials
| Service | Username | Password | Method |
|---------|----------|----------|---------|
| Grafana | admin | admin123 | kubectl |
| ArgoCD | admin | kubectl | kubectl |

## 🔧 Quick Commands
```bash
# Port forwarding
kubectl port-forward svc/argocd-server -n argocd 8080:443
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

---

**Ready? Start with Step 1!**
