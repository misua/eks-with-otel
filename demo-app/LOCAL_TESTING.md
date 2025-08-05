# Local Testing Guide for EKS OpenTelemetry Demo App

This guide provides comprehensive instructions for testing the Go CRUD application locally.

## 🏃‍♂️ Quick Start Options

### Option 1: Direct Go Execution (Fastest)
```bash
# Navigate to demo app directory
cd /home/charles.pino/Desktop/eks-with-otel/demo-app

# Install dependencies
go mod download

# Run the application
go run cmd/api/main.go
```

### Option 2: Build and Run Binary
```bash
# Build the application
go build -o demo-app ./cmd/api

# Run the binary
./demo-app
```

### Option 3: Docker Build and Run
```bash
# Build Docker image
docker build -t eks-otel-demo:latest .

# Run container
docker run -p 8080:8080 eks-otel-demo:latest
```

## 🧪 Automated Testing

### Run the Test Script
```bash
# Make sure the app is running first (use any option above)
# Then in another terminal:
./test-local.sh
```

This script will:
- ✅ Test health check endpoint
- ✅ Get service information
- ✅ Create a new item
- ✅ List all items
- ✅ Get specific item by ID
- ✅ Update the item
- ✅ Delete the item
- ✅ Verify deletion

## 🔍 Manual Testing Commands

### Basic Health Checks
```bash
# Health check
curl http://localhost:8080/health

# Service info
curl http://localhost:8080/
```

### CRUD Operations
```bash
# Create an item
curl -X POST http://localhost:8080/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"name": "My Test Item", "description": "Testing the CRUD API"}'

# List all items
curl http://localhost:8080/api/v1/items

# Get specific item (replace {id} with actual ID)
curl http://localhost:8080/api/v1/items/{id}

# Update item
curl -X PUT http://localhost:8080/api/v1/items/{id} \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Item", "description": "This item was updated"}'

# Delete item
curl -X DELETE http://localhost:8080/api/v1/items/{id}
```

## 🐳 Docker Testing Details

### Build Options
```bash
# Standard build
docker build -t eks-otel-demo:latest .

# Build with specific tag
docker build -t eks-otel-demo:v1.0.0 .

# Build with no cache (clean build)
docker build --no-cache -t eks-otel-demo:latest .
```

### Run Options
```bash
# Basic run
docker run -p 8080:8080 eks-otel-demo:latest

# Run with custom port
docker run -p 9090:8080 -e PORT=8080 eks-otel-demo:latest

# Run with custom OTEL endpoint
docker run -p 8080:8080 \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 \
  eks-otel-demo:latest

# Run in background (detached)
docker run -d -p 8080:8080 --name demo-app eks-otel-demo:latest

# View logs
docker logs demo-app

# Stop container
docker stop demo-app
docker rm demo-app
```

## 📊 What to Observe During Testing

### 1. Application Logs
When running locally, you'll see structured JSON logs like:
```json
{
  "timestamp": "2025-01-27T10:35:47Z",
  "level": "info",
  "message": "HTTP request completed successfully",
  "method": "GET",
  "path": "/api/v1/items",
  "status_code": 200,
  "latency": "1.234ms",
  "client_ip": "127.0.0.1",
  "trace_id": "abc123...",
  "span_id": "def456..."
}
```

### 2. OpenTelemetry Traces
Even though traces won't be sent to Tempo locally (no collector), you'll see:
- Trace initialization messages
- Span creation for each HTTP request
- Span attributes with business context

### 3. Error Handling
Test error scenarios:
```bash
# Try to get non-existent item
curl http://localhost:8080/api/v1/items/non-existent-id

# Try to create item with invalid JSON
curl -X POST http://localhost:8080/api/v1/items \
  -H "Content-Type: application/json" \
  -d '{"invalid": json}'

# Try to update non-existent item
curl -X PUT http://localhost:8080/api/v1/items/non-existent-id \
  -H "Content-Type: application/json" \
  -d '{"name": "Test"}'
```

## 🔧 Environment Variables for Local Testing

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP server port |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://otel-collector.tracing.svc.cluster.local:4318` | OTEL endpoint (won't work locally) |
| `OTEL_SERVICE_NAME` | `eks-otel-demo` | Service name for tracing |
| `OTEL_SERVICE_VERSION` | `1.0.0` | Service version |

### Custom Environment Example
```bash
# Run with custom settings
PORT=9090 OTEL_SERVICE_NAME=my-demo-app go run cmd/api/main.go
```

## 🚨 Troubleshooting

### Common Issues

**1. Port already in use:**
```bash
# Check what's using port 8080
lsof -i :8080

# Use different port
PORT=9090 go run cmd/api/main.go
```

**2. Docker build fails:**
```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
docker build --no-cache -t eks-otel-demo:latest .
```

**3. Dependencies not found:**
```bash
# Clean and reinstall Go modules
go clean -modcache
go mod download
```

**4. Permission denied on test script:**
```bash
chmod +x test-local.sh
```

## ✅ Expected Test Results

### Successful Health Check
```json
{
  "status": "healthy",
  "timestamp": "2025-01-27T10:35:47Z"
}
```

### Successful Item Creation
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "My Test Item",
  "description": "Testing the CRUD API",
  "created_at": "2025-01-27T10:35:47Z",
  "updated_at": "2025-01-27T10:35:47Z"
}
```

### Successful Items List
```json
{
  "items": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "name": "My Test Item",
      "description": "Testing the CRUD API",
      "created_at": "2025-01-27T10:35:47Z",
      "updated_at": "2025-01-27T10:35:47Z"
    }
  ],
  "total": 1
}
```

## 🎯 Next Steps After Local Testing

Once local testing is successful:
1. ✅ Verify all CRUD operations work
2. ✅ Confirm structured logging output
3. ✅ Check Docker build and run
4. 🚀 Deploy to EKS cluster
5. 📊 Validate observability in Grafana
