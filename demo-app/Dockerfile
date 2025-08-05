# Multi-stage Dockerfile for Go application with observability

# Build stage
FROM golang:1.23-alpine AS builder

# Set working directory
WORKDIR /app

# Install git (needed for go mod download)
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the main application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./cmd/api

# Build the load generator
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o loadgen ./cmd/loadgen

# Runtime stage
FROM alpine:3.18

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy binaries from builder stage
COPY --from=builder /app/main .
COPY --from=builder /app/loadgen .

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Set environment variables for OpenTelemetry
ENV PORT=8080
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.tracing.svc.cluster.local:4318
ENV OTEL_SERVICE_NAME=eks-otel-demo
ENV OTEL_SERVICE_VERSION=1.0.0

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the application
CMD ["./main"]
