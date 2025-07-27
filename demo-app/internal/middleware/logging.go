package middleware

import (
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"go.opentelemetry.io/otel/trace"
)

// InitLogger initializes structured logging with JSON format
func InitLogger() *logrus.Logger {
	logger := logrus.New()
	
	// Set JSON formatter for structured logging
	logger.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: time.RFC3339,
		FieldMap: logrus.FieldMap{
			logrus.FieldKeyTime:  "timestamp",
			logrus.FieldKeyLevel: "level",
			logrus.FieldKeyMsg:   "message",
		},
	})
	
	// Set output to stdout
	logger.SetOutput(os.Stdout)
	
	// Set log level
	logger.SetLevel(logrus.InfoLevel)
	
	return logger
}

// LoggingMiddleware creates a Gin middleware for structured logging with trace correlation
func LoggingMiddleware(logger *logrus.Logger) gin.HandlerFunc {
	return gin.LoggerWithFormatter(func(param gin.LogFormatterParams) string {
		// Extract trace information from context
		spanCtx := trace.SpanContextFromContext(param.Request.Context())
		
		fields := logrus.Fields{
			"method":      param.Method,
			"path":        param.Path,
			"status_code": param.StatusCode,
			"latency":     param.Latency.String(),
			"client_ip":   param.ClientIP,
			"user_agent":  param.Request.UserAgent(),
		}
		
		// Add trace information if available
		if spanCtx.IsValid() {
			fields["trace_id"] = spanCtx.TraceID().String()
			fields["span_id"] = spanCtx.SpanID().String()
		}
		
		// Add error information if present
		if param.ErrorMessage != "" {
			fields["error"] = param.ErrorMessage
		}
		
		// Log based on status code
		if param.StatusCode >= 500 {
			logger.WithFields(fields).Error("HTTP request completed with server error")
		} else if param.StatusCode >= 400 {
			logger.WithFields(fields).Warn("HTTP request completed with client error")
		} else {
			logger.WithFields(fields).Info("HTTP request completed successfully")
		}
		
		// Return empty string since we're handling logging ourselves
		return ""
	})
}

// RecoveryMiddleware creates a Gin middleware for panic recovery with logging
func RecoveryMiddleware(logger *logrus.Logger) gin.HandlerFunc {
	return gin.RecoveryWithWriter(os.Stdout, func(c *gin.Context, recovered interface{}) {
		// Extract trace information
		spanCtx := trace.SpanContextFromContext(c.Request.Context())
		
		fields := logrus.Fields{
			"method":    c.Request.Method,
			"path":      c.Request.URL.Path,
			"client_ip": c.ClientIP(),
			"panic":     recovered,
		}
		
		// Add trace information if available
		if spanCtx.IsValid() {
			fields["trace_id"] = spanCtx.TraceID().String()
			fields["span_id"] = spanCtx.SpanID().String()
		}
		
		logger.WithFields(fields).Error("Panic recovered in HTTP handler")
		
		c.AbortWithStatus(500)
	})
}
