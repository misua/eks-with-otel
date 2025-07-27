# EKS OpenTelemetry Demo Application

A simple Go CRUD application with OpenTelemetry tracing and structured logging for EKS observability.

## 🚀 Quick Start

### Local Testing
```bash
# Run directly
go run cmd/api/main.go

# Test all endpoints
./test-local.sh
```

### Docker Testing
```bash
# Build image
docker build -t eks-otel-demo:latest .

# Run container
docker run -p 8080:8080 eks-otel-demo:latest
```

### EKS Deployment
```bash
# Deploy to Kubernetes
kubectl apply -f k8s-deployment.yaml

# Check status
kubectl get pods -l app=eks-otel-demo
```

## 📋 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/api/v1/items` | List all items |
| POST | `/api/v1/items` | Create new item |
| GET | `/api/v1/items/{id}` | Get item by ID |
| PUT | `/api/v1/items/{id}` | Update item |
| DELETE | `/api/v1/items/{id}` | Delete item |

## 🧪 Testing

### Local Testing
```bash
# Test all CRUD endpoints automatically
./test-local.sh

# Or test manually
curl http://localhost:8080/health
curl -X POST http://localhost:8080/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "Testing"}'
```

### Docker Testing
```bash
# Build and test
docker build -t eks-otel-demo:latest .
docker run -p 8080:8080 eks-otel-demo:latest
./test-local.sh
```

**Note:** For local Docker testing, OTEL traces won't be sent (no collector), but the app works fine.

## 🤖 Automated Load Generation

### Generate Observability Data Automatically
```bash
# Run load generator (generates traces and logs automatically)
./run-loadgen.sh

# Custom configuration
./run-loadgen.sh http://localhost:8080 10m 5  # URL, duration, concurrency
```

### For EKS (after deployment)
```bash
# Port forward to access the service
kubectl port-forward service/eks-otel-demo-service 8080:80

# Run load generator against EKS
./run-loadgen.sh http://localhost:8080 15m 3
```

**What the load generator does:**
- ✅ **Continuous CRUD operations** - Creates, reads, updates, deletes items
- ✅ **Realistic traffic patterns** - Weighted random operations
- ✅ **Multiple concurrent workers** - Simulates real user load
- ✅ **Automatic trace generation** - Populates Tempo with distributed traces
- ✅ **Structured log generation** - Populates Loki with correlated logs
- ✅ **Statistics reporting** - Shows operation counts and success rates

## 🚀 EKS Deployment

### Build for EKS
```bash
# Build and tag for your registry
docker build -t your-registry/eks-otel-demo:latest .
docker push your-registry/eks-otel-demo:latest
```

### Deploy to Kubernetes
```bash
# Update image in k8s-deployment.yaml first
kubectl apply -f k8s-deployment.yaml

# Check deployment
kubectl get pods -l app=eks-otel-demo
kubectl logs -l app=eks-otel-demo
```

### EKS Configuration
In EKS, the app automatically connects to:
- **OpenTelemetry Collector** at `otel-collector.tracing.svc.cluster.local:4318`
- **Traces** → Tempo → Grafana
- **Logs** → Loki → Grafana
- **Full observability** with trace/log correlation

## 📊 What You'll See

### Structured Logs (JSON)
```json
{
  "timestamp": "2025-01-27T10:42:03Z",
  "level": "info",
  "message": "HTTP request completed",
  "method": "POST",
  "path": "/api/v1/items",
  "status_code": 201,
  "trace_id": "abc123...",
  "span_id": "def456..."
}
```

### OpenTelemetry Traces
- HTTP request spans
- Storage operation spans
- Business logic spans
- Error recording and status

## 🔧 Files
- `k8s-deployment.yaml` - Kubernetes deployment manifest
- `test-local.sh` - Automated testing script
- `Dockerfile` - Multi-stage container build
- `LOCAL_TESTING.md` - Detailed testing guide
