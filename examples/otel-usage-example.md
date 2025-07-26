# OpenTelemetry Collector Usage Guide

This guide shows how to send traces from your applications to the deployed OpenTelemetry Collector, which forwards them to Tempo.

## 🔗 Service Endpoints

The OpenTelemetry Collector is deployed in the `tracing` namespace and exposes the following endpoints:

### OTLP (OpenTelemetry Protocol)
- **gRPC**: `otel-collector.tracing.svc.cluster.local:4317`
- **HTTP**: `otel-collector.tracing.svc.cluster.local:4318`

### Jaeger Protocol (for compatibility)
- **gRPC**: `otel-collector.tracing.svc.cluster.local:14250`
- **Thrift HTTP**: `otel-collector.tracing.svc.cluster.local:14268`
- **Thrift Compact**: `otel-collector.tracing.svc.cluster.local:6831`

## 📝 Application Configuration Examples

### Go Application (using OpenTelemetry SDK)

```go
package main

import (
    "context"
    "log"
    
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
    "go.opentelemetry.io/otel/sdk/resource"
    semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

func initTracer() {
    // Create OTLP exporter
    exporter, err := otlptracegrpc.New(
        context.Background(),
        otlptracegrpc.WithEndpoint("otel-collector.tracing.svc.cluster.local:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        log.Fatal(err)
    }

    // Create resource
    res := resource.NewWithAttributes(
        semconv.SchemaURL,
        semconv.ServiceNameKey.String("my-go-app"),
        semconv.ServiceVersionKey.String("1.0.0"),
    )

    // Create tracer provider
    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(res),
    )

    otel.SetTracerProvider(tp)
}
```

### Environment Variables for Applications

```yaml
# Add these environment variables to your application pods
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.tracing.svc.cluster.local:4318"
  - name: OTEL_SERVICE_NAME
    value: "your-app-name"
  - name: OTEL_SERVICE_VERSION
    value: "1.0.0"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.name=your-app-name,service.version=1.0.0"
```

### Kubernetes Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: app
        image: your-app:latest
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-collector.tracing.svc.cluster.local:4318"
        - name: OTEL_SERVICE_NAME
          value: "sample-app"
        - name: OTEL_SERVICE_VERSION
          value: "1.0.0"
        ports:
        - containerPort: 8080
```

## 🔍 Verification

### Check if traces are being received:

1. **Check OpenTelemetry Collector logs:**
   ```bash
   kubectl logs -n tracing -l app.kubernetes.io/name=opentelemetry-collector
   ```

2. **Check Tempo logs:**
   ```bash
   kubectl logs -n tracing -l app.kubernetes.io/name=tempo
   ```

3. **Query traces in Grafana:**
   - Port forward to Grafana: `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`
   - Open http://localhost:3000
   - Go to Explore → Select Tempo as data source
   - Search for traces by service name or trace ID

## 🚀 Quick Test

You can test the setup by deploying a simple trace generator:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: trace-generator
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: trace-generator
        image: jaegertracing/jaeger-client-go:latest
        command: ["sh", "-c"]
        args:
        - |
          echo "Sending test traces to OpenTelemetry Collector..."
          # This would send test traces - replace with actual trace generation
          sleep 30
      restartPolicy: Never
```

## 📊 Monitoring

The OpenTelemetry Collector exposes metrics on port 8888 that are automatically scraped by Prometheus:
- Traces received
- Traces exported
- Processing errors
- Resource utilization

Check these metrics in Grafana under the Prometheus data source.
