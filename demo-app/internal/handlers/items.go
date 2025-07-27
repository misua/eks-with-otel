package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"github.com/misua/eks-with-otel/demo-app/internal/models"
	"github.com/misua/eks-with-otel/demo-app/internal/storage"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

var tracer = otel.Tracer("handlers")

// ItemHandler handles HTTP requests for items
type ItemHandler struct {
	storage *storage.MemoryStorage
	logger  *logrus.Logger
}

// NewItemHandler creates a new item handler
func NewItemHandler(storage *storage.MemoryStorage, logger *logrus.Logger) *ItemHandler {
	return &ItemHandler{
		storage: storage,
		logger:  logger,
	}
}

// CreateItem handles POST /api/v1/items
func (h *ItemHandler) CreateItem(c *gin.Context) {
	ctx, span := tracer.Start(c.Request.Context(), "handler.create_item")
	defer span.End()

	// Extract trace information for logging
	spanCtx := trace.SpanContextFromContext(ctx)
	logFields := logrus.Fields{
		"trace_id": spanCtx.TraceID().String(),
		"span_id":  spanCtx.SpanID().String(),
		"method":   "POST",
		"endpoint": "/api/v1/items",
	}

	var req struct {
		Name        string `json:"name" binding:"required"`
		Description string `json:"description"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		span.RecordError(err)
		span.SetAttributes(attribute.String("error.type", "validation_error"))
		
		h.logger.WithFields(logFields).WithError(err).Error("Invalid request payload")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request payload"})
		return
	}

	span.SetAttributes(
		attribute.String("item.name", req.Name),
		attribute.String("item.description", req.Description),
	)

	item := models.NewItem(req.Name, req.Description)
	createdItem, err := h.storage.Create(ctx, item)
	if err != nil {
		span.RecordError(err)
		span.SetAttributes(attribute.String("error.type", "storage_error"))
		
		h.logger.WithFields(logFields).WithError(err).Error("Failed to create item")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create item"})
		return
	}

	span.SetAttributes(
		attribute.String("item.id", createdItem.ID),
		attribute.String("response.status", "success"),
	)

	logFields["item_id"] = createdItem.ID
	logFields["item_name"] = createdItem.Name
	h.logger.WithFields(logFields).Info("Item created successfully")

	c.JSON(http.StatusCreated, createdItem)
}

// GetItems handles GET /api/v1/items
func (h *ItemHandler) GetItems(c *gin.Context) {
	ctx, span := tracer.Start(c.Request.Context(), "handler.get_items")
	defer span.End()

	spanCtx := trace.SpanContextFromContext(ctx)
	logFields := logrus.Fields{
		"trace_id": spanCtx.TraceID().String(),
		"span_id":  spanCtx.SpanID().String(),
		"method":   "GET",
		"endpoint": "/api/v1/items",
	}

	items, err := h.storage.GetAll(ctx)
	if err != nil {
		span.RecordError(err)
		span.SetAttributes(attribute.String("error.type", "storage_error"))
		
		h.logger.WithFields(logFields).WithError(err).Error("Failed to retrieve items")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve items"})
		return
	}

	span.SetAttributes(
		attribute.Int("items.count", len(items)),
		attribute.String("response.status", "success"),
	)

	logFields["items_count"] = len(items)
	h.logger.WithFields(logFields).Info("Items retrieved successfully")

	c.JSON(http.StatusOK, gin.H{"items": items, "count": len(items)})
}

// GetItem handles GET /api/v1/items/:id
func (h *ItemHandler) GetItem(c *gin.Context) {
	ctx, span := tracer.Start(c.Request.Context(), "handler.get_item")
	defer span.End()

	id := c.Param("id")
	span.SetAttributes(attribute.String("item.id", id))

	spanCtx := trace.SpanContextFromContext(ctx)
	logFields := logrus.Fields{
		"trace_id": spanCtx.TraceID().String(),
		"span_id":  spanCtx.SpanID().String(),
		"method":   "GET",
		"endpoint": "/api/v1/items/:id",
		"item_id":  id,
	}

	item, err := h.storage.GetByID(ctx, id)
	if err != nil {
		if err == storage.ErrItemNotFound {
			span.SetAttributes(
				attribute.String("error.type", "not_found"),
				attribute.Bool("item.found", false),
			)
			
			h.logger.WithFields(logFields).Warn("Item not found")
			c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
			return
		}

		span.RecordError(err)
		span.SetAttributes(attribute.String("error.type", "storage_error"))
		
		h.logger.WithFields(logFields).WithError(err).Error("Failed to retrieve item")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve item"})
		return
	}

	span.SetAttributes(
		attribute.Bool("item.found", true),
		attribute.String("item.name", item.Name),
		attribute.String("response.status", "success"),
	)

	logFields["item_name"] = item.Name
	h.logger.WithFields(logFields).Info("Item retrieved successfully")

	c.JSON(http.StatusOK, item)
}

// UpdateItem handles PUT /api/v1/items/:id
func (h *ItemHandler) UpdateItem(c *gin.Context) {
	ctx, span := tracer.Start(c.Request.Context(), "handler.update_item")
	defer span.End()

	id := c.Param("id")
	span.SetAttributes(attribute.String("item.id", id))

	spanCtx := trace.SpanContextFromContext(ctx)
	logFields := logrus.Fields{
		"trace_id": spanCtx.TraceID().String(),
		"span_id":  spanCtx.SpanID().String(),
		"method":   "PUT",
		"endpoint": "/api/v1/items/:id",
		"item_id":  id,
	}

	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		span.RecordError(err)
		span.SetAttributes(attribute.String("error.type", "validation_error"))
		
		h.logger.WithFields(logFields).WithError(err).Error("Invalid request payload")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request payload"})
		return
	}

	span.SetAttributes(
		attribute.String("item.new_name", req.Name),
		attribute.String("item.new_description", req.Description),
	)

	updatedItem, err := h.storage.Update(ctx, id, req.Name, req.Description)
	if err != nil {
		if err == storage.ErrItemNotFound {
			span.SetAttributes(
				attribute.String("error.type", "not_found"),
				attribute.Bool("item.found", false),
			)
			
			h.logger.WithFields(logFields).Warn("Item not found for update")
			c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
			return
		}

		span.RecordError(err)
		span.SetAttributes(attribute.String("error.type", "storage_error"))
		
		h.logger.WithFields(logFields).WithError(err).Error("Failed to update item")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update item"})
		return
	}

	span.SetAttributes(
		attribute.Bool("item.found", true),
		attribute.String("item.updated_name", updatedItem.Name),
		attribute.String("response.status", "success"),
	)

	logFields["item_name"] = updatedItem.Name
	h.logger.WithFields(logFields).Info("Item updated successfully")

	c.JSON(http.StatusOK, updatedItem)
}

// DeleteItem handles DELETE /api/v1/items/:id
func (h *ItemHandler) DeleteItem(c *gin.Context) {
	ctx, span := tracer.Start(c.Request.Context(), "handler.delete_item")
	defer span.End()

	id := c.Param("id")
	span.SetAttributes(attribute.String("item.id", id))

	spanCtx := trace.SpanContextFromContext(ctx)
	logFields := logrus.Fields{
		"trace_id": spanCtx.TraceID().String(),
		"span_id":  spanCtx.SpanID().String(),
		"method":   "DELETE",
		"endpoint": "/api/v1/items/:id",
		"item_id":  id,
	}

	err := h.storage.Delete(ctx, id)
	if err != nil {
		if err == storage.ErrItemNotFound {
			span.SetAttributes(
				attribute.String("error.type", "not_found"),
				attribute.Bool("item.found", false),
			)
			
			h.logger.WithFields(logFields).Warn("Item not found for deletion")
			c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
			return
		}

		span.RecordError(err)
		span.SetAttributes(attribute.String("error.type", "storage_error"))
		
		h.logger.WithFields(logFields).WithError(err).Error("Failed to delete item")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete item"})
		return
	}

	span.SetAttributes(
		attribute.Bool("item.found", true),
		attribute.String("response.status", "success"),
	)

	h.logger.WithFields(logFields).Info("Item deleted successfully")

	c.JSON(http.StatusOK, gin.H{"message": "Item deleted successfully"})
}

// HealthCheck handles GET /health
func (h *ItemHandler) HealthCheck(c *gin.Context) {
	ctx, span := tracer.Start(c.Request.Context(), "handler.health_check")
	defer span.End()

	spanCtx := trace.SpanContextFromContext(ctx)
	logFields := logrus.Fields{
		"trace_id": spanCtx.TraceID().String(),
		"span_id":  spanCtx.SpanID().String(),
		"method":   "GET",
		"endpoint": "/health",
	}

	// Check storage health by counting items
	count, err := h.storage.Count(ctx)
	if err != nil {
		span.RecordError(err)
		span.SetAttributes(
			attribute.String("health.status", "unhealthy"),
			attribute.String("error.type", "storage_error"),
		)
		
		h.logger.WithFields(logFields).WithError(err).Error("Health check failed")
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status": "unhealthy",
			"error":  "Storage unavailable",
		})
		return
	}

	span.SetAttributes(
		attribute.String("health.status", "healthy"),
		attribute.Int("storage.item_count", count),
	)

	logFields["item_count"] = count
	h.logger.WithFields(logFields).Info("Health check passed")

	c.JSON(http.StatusOK, gin.H{
		"status":     "healthy",
		"item_count": count,
		"service":    "eks-otel-demo",
	})
}
