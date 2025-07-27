package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/misua/eks-with-otel/demo-app/internal/handlers"
	"github.com/misua/eks-with-otel/demo-app/internal/middleware"
	"github.com/misua/eks-with-otel/demo-app/internal/storage"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

const (
	serviceName    = "eks-otel-demo"
	serviceVersion = "1.0.0"
)

func main() {
	// Get configuration from environment variables
	port := getEnv("PORT", "8080")
	otlpEndpoint := getEnv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.tracing.svc.cluster.local:4318")

	// Initialize OpenTelemetry tracing
	cleanup, err := middleware.InitTracer(serviceName, serviceVersion, otlpEndpoint)
	if err != nil {
		log.Fatalf("Failed to initialize OpenTelemetry: %v", err)
	}
	defer cleanup()

	// Initialize structured logger
	logger := middleware.InitLogger()
	logger.WithField("service", serviceName).Info("Starting application")

	// Initialize storage
	memStorage := storage.NewMemoryStorage()

	// Initialize handlers
	itemHandler := handlers.NewItemHandler(memStorage, logger)

	// Set Gin mode
	gin.SetMode(gin.ReleaseMode)

	// Create Gin router
	router := gin.New()

	// Add middleware
	router.Use(middleware.RecoveryMiddleware(logger))
	router.Use(middleware.LoggingMiddleware(logger))
	router.Use(otelgin.Middleware(serviceName)) // OpenTelemetry middleware

	// Add CORS middleware for development
	router.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization")
		
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		
		c.Next()
	})

	// Health check endpoint
	router.GET("/health", itemHandler.HealthCheck)
	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": serviceName,
			"version": serviceVersion,
			"status":  "running",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		v1.GET("/items", itemHandler.GetItems)
		v1.GET("/items/:id", itemHandler.GetItem)
		v1.POST("/items", itemHandler.CreateItem)
		v1.PUT("/items/:id", itemHandler.UpdateItem)
		v1.DELETE("/items/:id", itemHandler.DeleteItem)
	}

	// Create HTTP server
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		logger.WithField("port", port).Info("Starting HTTP server")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.WithError(err).Fatal("Failed to start HTTP server")
		}
	}()

	// Wait for interrupt signal for graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		logger.WithError(err).Error("Server forced to shutdown")
	} else {
		logger.Info("Server shutdown completed")
	}
}

// getEnv gets environment variable with fallback
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
