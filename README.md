# EKS with OpenTelemetry Observability Stack

A complete, production-ready observability solution for Amazon EKS with OpenTelemetry, featuring distributed tracing, structured logging, metrics collection, and a demo Go CRUD application.

## 🎯 What You'll Build

- ✅ **Complete EKS Observability Stack** - Prometheus, Loki, Tempo, Grafana, OpenTelemetry Collector
- ✅ **Demo Go CRUD Application** - With OpenTelemetry tracing and structured logging
- ✅ **Automated Load Generator** - Continuously generates observability data
- ✅ **Unified Grafana Dashboards** - Correlated logs, traces, and metrics
- ✅ **GitOps with ArgoCD** - Automated deployment and management

## 🚀 Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Helm 3.x installed
- Docker installed
- Go 1.21+ installed
- An existing EKS cluster (or use the setup script to create one)

---

# 📋 Step-by-Step Deployment Guide

## Phase 1: Infrastructure Setup

### Step 1: Deploy EKS Observability Stack
```bash
# Clone the repository
git clone <your-repo-url>
cd eks-with-otel

# Make setup script executable
chmod +x setup-infrastructure.sh

# Deploy the complete observability stack
./setup-infrastructure.sh
```

**What this deploys:**
- ✅ Prometheus (metrics collection and storage)
- ✅ Grafana (unified visualization dashboard)
- ✅ Tempo (distributed tracing storage)
- ✅ Loki + Promtail (log aggregation and collection)
- ✅ Enhanced OpenTelemetry Collector (multi-signal telemetry processing)
- ✅ ArgoCD (GitOps deployment platform)

### Step 2: Verify Infrastructure Deployment
```bash
# Check all pods are running (this may take 5-10 minutes)
kubectl get pods --all-namespaces

# Check specific namespaces
kubectl get pods -n monitoring
kubectl get pods -n tracing  
kubectl get pods -n logging
kubectl get pods -n argocd

# Wait for all pods to be in Running state
kubectl wait --for=condition=ready pod --all --all-namespaces --timeout=600s
```

### Step 3: Access Grafana Dashboard
```bash
# Get Grafana admin password
echo "Grafana Password:"
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Port forward to access Grafana
kubectl port-forward --namespace monitoring svc/grafana 3000:80

# Open browser: http://localhost:3000
# Username: admin
# Password: (from command above)
```

**Verify in Grafana:**
- ✅ Data Sources: Prometheus, Loki, Tempo should all be connected
- ✅ Dashboards: Default dashboards should be available
- ✅ Explore: You should be able to query each data source

---

## Phase 2: Demo Application Deployment

### Step 4: Prepare Demo Application
```bash
# Navigate to demo app directory
cd demo-app

# Test build locally (optional)
go mod download
go build -o demo-app ./cmd/api
go build -o loadgen ./cmd/loadgen

# Clean up test binaries
rm -f demo-app loadgen
```

### Step 5: Build and Push Docker Image

**For AWS ECR:**
```bash
# Set your AWS account ID and region
AWS_ACCOUNT_ID="123456789012"  # Replace with your AWS account ID
AWS_REGION="us-west-2"         # Replace with your region
REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
IMAGE_NAME="eks-otel-demo"

# Create ECR repository (if it doesn't exist)
aws ecr create-repository --repository-name $IMAGE_NAME --region $AWS_REGION || true

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY

# Build Docker image
docker build -t $IMAGE_NAME:latest .

# Tag for registry
docker tag $IMAGE_NAME:latest $REGISTRY/$IMAGE_NAME:latest

# Push to registry
docker push $REGISTRY/$IMAGE_NAME:latest

echo "Image pushed to: $REGISTRY/$IMAGE_NAME:latest"
```

**For other registries (Docker Hub, etc.):**
```bash
# Replace with your registry
REGISTRY="your-dockerhub-username"  # or your-registry.com
IMAGE_NAME="eks-otel-demo"

# Build and push
docker build -t $IMAGE_NAME:latest .
docker tag $IMAGE_NAME:latest $REGISTRY/$IMAGE_NAME:latest
docker push $REGISTRY/$IMAGE_NAME:latest
```

### Step 6: Update Kubernetes Manifests
```bash
# Update the image reference in deployment files
sed -i "s|your-registry|$REGISTRY|g" k8s-deployment.yaml
sed -i "s|your-registry|$REGISTRY|g" k8s-loadgen.yaml

# Verify the changes
grep "image:" k8s-deployment.yaml
grep "image:" k8s-loadgen.yaml
```

### Step 7: Deploy Demo Application to EKS
```bash
# Deploy the demo CRUD application
kubectl apply -f k8s-deployment.yaml

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=300s deployment/eks-otel-demo

# Verify deployment
kubectl get pods -l app=eks-otel-demo
kubectl get service eks-otel-demo-service

# Check application logs
kubectl logs -l app=eks-otel-demo --tail=20
```

### Step 8: Deploy Automated Load Generator
```bash
# Deploy continuous load generator
kubectl apply -f k8s-loadgen.yaml

# Wait for load generator to start
kubectl wait --for=condition=available --timeout=300s deployment/eks-otel-loadgen

# Verify load generator is running
kubectl get pods -l app=eks-otel-loadgen

# Check load generator logs
kubectl logs -l app=eks-otel-loadgen --tail=20
```

---

## Phase 3: Validation & Testing

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
  -d '{"name": "Test Item from EKS", "description": "Testing the deployed application"}'

# List all items
curl http://localhost:8080/api/v1/items

# Get service info
curl http://localhost:8080/
```

### Step 10: Validate Observability Data in Grafana

**Access Grafana (if not already open):**
```bash
kubectl port-forward --namespace monitoring svc/grafana 3000:80
# Open: http://localhost:3000
```

#### Check Logs in Loki
1. Go to **Explore** → Select **Loki** data source
2. Use query: `{service_name="eks-otel-demo"}`
3. You should see structured JSON logs with trace correlation
4. Look for fields: `trace_id`, `span_id`, `method`, `path`, `status_code`

#### Check Traces in Tempo
1. Go to **Explore** → Select **Tempo** data source  
2. Search by **Service Name**: `eks-otel-demo`
3. You should see distributed traces for HTTP requests and storage operations
4. Click on traces to see detailed span information

#### Check Metrics in Prometheus
1. Go to **Explore** → Select **Prometheus** data source
2. Try queries:
   - `http_requests_total{service="eks-otel-demo"}`
   - `http_request_duration_seconds{service="eks-otel-demo"}`
   - `up{job="eks-otel-demo"}`

#### Verify Trace/Log Correlation
1. In **Loki**, find a log entry with a `trace_id`
2. Copy the `trace_id` value
3. In **Tempo**, search by that trace ID
4. You should see the corresponding trace with all related spans

---

## Phase 4: Continuous Load Testing

### Step 11: Monitor Automated Load Generation
```bash
# Watch load generator in action
kubectl logs -l app=eks-otel-loadgen -f

# Watch demo app handling requests
kubectl logs -l app=eks-otel-demo -f

# Check resource usage
kubectl top pods -l app=eks-otel-demo
kubectl top pods -l app=eks-otel-loadgen
```

### Step 12: Optional - Run Additional Load Testing
```bash
# Port forward demo app (if not already done)
kubectl port-forward service/eks-otel-demo-service 8080:80

# Run local load generator for intensive testing
./run-loadgen.sh http://localhost:8080 10m 5
```

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
    end
    
    subgraph External ["External Services"]
        Internet["Internet Users"]
        GitHub["GitHub Repository"]
    end
    
    style VPC fill:#f9f,stroke:#333,stroke-width:2px
    style Private_Subnets fill:#bbf,stroke:#333,stroke-width:1px
    style Public_Subnets fill:#bfb,stroke:#333,stroke-width:1px
    
    classDef awsFill fill:#FF9900,stroke:#333,stroke-width:1px;
    classDef k8sFill fill:#326ce5,stroke:#fff,stroke-width:1px,color:#fff;
    classDef monitoringFill fill:#7928CA,stroke:#fff,stroke-width:1px,color:#fff;
    classDef tracingFill fill:#FF4F8B,stroke:#fff,stroke-width:1px,color:#fff;
    classDef gitopsFill fill:#EF7A08,stroke:#fff,stroke-width:1px,color:#fff;
    classDef plannedFill fill:#808080,stroke:#fff,stroke-width:1px,color:#fff,stroke-dasharray: 5 5;
    
    class Worker_Nodes,API_Server,ETCD k8sFill
    class Prometheus,Grafana monitoringFill
    class Tempo tracingFill
    class ArgoCD,ArgoRollouts gitopsFill
    class ArgoRollouts plannedFill
    class IGW,NAT awsFill
    
    Internet --- IGW
    IGW --- NAT
    NAT --- Worker_Nodes
    GitHub -.-> ArgoCD
    ArgoCD ==> Prometheus
    ArgoCD ==> Grafana
    ArgoCD ==> Tempo
    ArgoCD -.-> ArgoRollouts
    Worker_Nodes -.-> Prometheus
    Worker_Nodes -.-> Tempo
    Prometheus --- Grafana
```

## 📝 Logging Infrastructure

The logging stack provides comprehensive log aggregation and visualization using Loki and Promtail, integrated with Grafana for unified observability.

### Components

#### Loki (Log Aggregation)
- **Purpose**: Horizontally scalable log aggregation system
- **Storage**: Filesystem-based storage with 7-day retention
- **Architecture**: SimpleScalable deployment mode with separate read/write/backend components
- **Integration**: Native Grafana data source with trace correlation

#### Promtail (Log Collection)
- **Purpose**: Log shipping agent that collects logs from Kubernetes
- **Deployment**: DaemonSet running on all nodes
- **Sources**: 
  - Kubernetes pod logs (stdout/stderr)
  - Node system logs (journal)
- **Processing**: CRI log parsing, label extraction, and filtering

### Log Flow Architecture

```mermaid
flowchart LR
    subgraph "Kubernetes Cluster"
        subgraph "Application Pods"
            App1["App Pod 1"]
            App2["App Pod 2"]
            App3["App Pod N"]
        end
        
        subgraph "System Components"
            Kubelet["Kubelet"]
            SystemD["SystemD Journal"]
        end
        
        subgraph "Log Collection (DaemonSet)"
            PT1["Promtail Agent 1"]
            PT2["Promtail Agent 2"]
            PT3["Promtail Agent N"]
        end
        
        subgraph "Logging Namespace"
            LokiGW["Loki Gateway"]
            LokiWrite["Loki Write"]
            LokiRead["Loki Read"]
            LokiBackend["Loki Backend"]
        end
        
        subgraph "Monitoring Namespace"
            Grafana["Grafana Dashboard"]
        end
    end
    
    App1 --> PT1
    App2 --> PT2
    App3 --> PT3
    Kubelet --> PT1
    SystemD --> PT2
    
    PT1 --> LokiGW
    PT2 --> LokiGW
    PT3 --> LokiGW
    
    LokiGW --> LokiWrite
    LokiGW --> LokiRead
    LokiWrite --> LokiBackend
    LokiRead --> LokiBackend
    
    LokiRead --> Grafana
    
    style App1 fill:#e1f5fe
    style App2 fill:#e1f5fe
    style App3 fill:#e1f5fe
    style PT1 fill:#f3e5f5
    style PT2 fill:#f3e5f5
    style PT3 fill:#f3e5f5
    style LokiGW fill:#e8f5e8
    style LokiWrite fill:#e8f5e8
    style LokiRead fill:#e8f5e8
    style LokiBackend fill:#e8f5e8
    style Grafana fill:#fff3e0
```

### Configuration Files

- **`loki-values.yaml`**: Loki deployment configuration with SimpleScalable mode
- **`promtail-values.yaml`**: Promtail DaemonSet configuration for log collection
- **`prometheus-values.yaml`**: Updated Grafana configuration with Loki data source

### Log Labels and Parsing

Promtail automatically adds these labels to collected logs:
- `namespace`: Kubernetes namespace
- `pod`: Pod name
- `container`: Container name
- `app`: Application label (if present)
- `service`: Service name (if present)
- `node`: Node name
- `job`: Collection job name

### Accessing Logs

1. **Via Grafana**: 
   - Access Grafana dashboard
   - Use "Explore" tab with Loki data source
   - Query logs using LogQL syntax

2. **Direct Loki Access**:
   ```bash
   kubectl port-forward svc/loki-gateway -n logging 3100:80
   curl "http://localhost:3100/loki/api/v1/query_range?query={namespace=\"default\"}"
   ```

3. **Common LogQL Queries**:
   ```logql
   # All logs from a specific namespace
   {namespace="default"}
   
   # Error logs across all pods
   {} |= "error" or "ERROR"
   
   # Logs from specific application
   {app="my-app"} | json
   
   # Rate of error logs
   rate({} |= "error" [5m])
   ```

## 🔗 OpenTelemetry Collector

The enhanced OpenTelemetry Collector serves as the central hub for all observability data, collecting, processing, and routing traces, metrics, and logs to their respective backends.

### Architecture Overview

The collector is deployed as a Kubernetes deployment with 2 replicas, providing high availability and load distribution for telemetry data processing.

```mermaid
flowchart TB
    subgraph "Applications"
        App1["Application 1"]
        App2["Application 2"]
        App3["Application N"]
    end
    
    subgraph "OpenTelemetry Collector"
        subgraph "Receivers"
            OTLP["OTLP Receiver<br/>(gRPC/HTTP)"]
            Jaeger["Jaeger Receiver<br/>(Legacy Support)"]
            Prometheus["Prometheus Receiver<br/>(Metrics Scraping)"]
            HostMetrics["Host Metrics<br/>(System Metrics)"]
        end
        
        subgraph "Processors"
            Batch["Batch Processor"]
            Memory["Memory Limiter"]
            K8sAttrib["K8s Attributes"]
            Resource["Resource Detection"]
            Transform["Transform Processor"]
        end
        
        subgraph "Exporters"
            TempoExp["Tempo Exporter"]
            LokiExp["Loki Exporter"]
            PrometheusExp["Prometheus Remote Write"]
            Debug["Debug Exporter"]
        end
    end
    
    subgraph "Backends"
        Tempo["Tempo<br/>(Traces)"]
        Loki["Loki<br/>(Logs)"]
        PrometheusDB["Prometheus<br/>(Metrics)"]
    end
    
    App1 --> OTLP
    App2 --> OTLP
    App3 --> OTLP
    
    OTLP --> Batch
    Jaeger --> Batch
    Prometheus --> Batch
    HostMetrics --> Batch
    
    Batch --> Memory
    Memory --> K8sAttrib
    K8sAttrib --> Resource
    Resource --> Transform
    
    Transform --> TempoExp
    Transform --> LokiExp
    Transform --> PrometheusExp
    Transform --> Debug
    
    TempoExp --> Tempo
    LokiExp --> Loki
    PrometheusExp --> PrometheusDB
    
    style OTLP fill:#e1f5fe
    style Batch fill:#f3e5f5
    style Memory fill:#f3e5f5
    style K8sAttrib fill:#f3e5f5
    style TempoExp fill:#e8f5e8
    style LokiExp fill:#e8f5e8
    style PrometheusExp fill:#e8f5e8
```

### Enhanced Features

#### Multi-Signal Processing
- **Traces**: OTLP and Jaeger protocol support with correlation IDs
- **Metrics**: Application metrics via OTLP + system metrics via host metrics receiver
- **Logs**: OTLP log ingestion with structured log processing

#### Kubernetes Integration
- **K8s Attributes Processor**: Automatically enriches telemetry with Kubernetes metadata
- **Resource Detection**: Identifies cluster, node, and pod information
- **RBAC Configuration**: Proper permissions for Kubernetes API access

#### Advanced Processing
- **Batch Processing**: Optimized data transmission with configurable batch sizes
- **Memory Management**: Prevents OOM with memory limiting and spike protection
- **Attribute Enhancement**: Consistent metadata across all signals
- **Transform Processing**: Log parsing and enrichment

### Configuration Files

- **`otel-collector-values.yaml`**: Enhanced multi-signal collector configuration
- **`otel-collector-values.yaml.backup`**: Backup of original traces-only configuration
- **`validate-otel-config.sh`**: Configuration validation and testing script

### Data Pipelines

#### Traces Pipeline
```yaml
traces:
  receivers: [otlp, jaeger]
  processors: [memory_limiter, resourcedetection, k8sattributes, attributes, batch]
  exporters: [otlp/tempo, debug]
```

#### Metrics Pipeline
```yaml
metrics:
  receivers: [otlp, prometheus, hostmetrics]
  processors: [memory_limiter, resourcedetection, k8sattributes, attributes, batch]
  exporters: [prometheusremotewrite, debug]
```

#### Logs Pipeline
```yaml
logs:
  receivers: [otlp]
  processors: [memory_limiter, resourcedetection, k8sattributes, attributes, transform, batch]
  exporters: [loki, debug]
```

### Resource Configuration

- **CPU**: 1000m limit, 200m request (increased for multi-signal processing)
- **Memory**: 1Gi limit, 256Mi request (increased for buffering and processing)
- **Replicas**: 2 (high availability)

### Endpoints and Ports

| Protocol | Port | Purpose |
|----------|------|----------|
| OTLP gRPC | 4317 | Primary OpenTelemetry protocol |
| OTLP HTTP | 4318 | HTTP variant of OTLP |
| Jaeger gRPC | 14250 | Legacy Jaeger traces |
| Jaeger HTTP | 14268 | Legacy Jaeger traces |
| Jaeger UDP | 6831 | Legacy Jaeger traces |
| Metrics | 8888 | Collector self-monitoring |

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
