package storage

import (
	"context"
	"errors"
	"sync"

	"github.com/misua/eks-with-otel/demo-app/internal/models"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
)

var (
	ErrItemNotFound = errors.New("item not found")
	tracer          = otel.Tracer("storage")
)

// MemoryStorage provides in-memory storage for items with OpenTelemetry tracing
type MemoryStorage struct {
	items map[string]*models.Item
	mutex sync.RWMutex
}

// NewMemoryStorage creates a new in-memory storage instance
func NewMemoryStorage() *MemoryStorage {
	return &MemoryStorage{
		items: make(map[string]*models.Item),
	}
}

// Create stores a new item and returns it
func (s *MemoryStorage) Create(ctx context.Context, item *models.Item) (*models.Item, error) {
	ctx, span := tracer.Start(ctx, "storage.create_item")
	defer span.End()

	span.SetAttributes(
		attribute.String("item.id", item.ID),
		attribute.String("item.name", item.Name),
	)

	s.mutex.Lock()
	defer s.mutex.Unlock()

	s.items[item.ID] = item
	
	span.SetAttributes(attribute.Int("storage.total_items", len(s.items)))
	return item, nil
}

// GetByID retrieves an item by its ID
func (s *MemoryStorage) GetByID(ctx context.Context, id string) (*models.Item, error) {
	ctx, span := tracer.Start(ctx, "storage.get_item_by_id")
	defer span.End()

	span.SetAttributes(attribute.String("item.id", id))

	s.mutex.RLock()
	defer s.mutex.RUnlock()

	item, exists := s.items[id]
	if !exists {
		span.SetAttributes(attribute.Bool("item.found", false))
		span.RecordError(ErrItemNotFound)
		return nil, ErrItemNotFound
	}

	span.SetAttributes(
		attribute.Bool("item.found", true),
		attribute.String("item.name", item.Name),
	)
	return item, nil
}

// GetAll retrieves all items
func (s *MemoryStorage) GetAll(ctx context.Context) ([]*models.Item, error) {
	ctx, span := tracer.Start(ctx, "storage.get_all_items")
	defer span.End()

	s.mutex.RLock()
	defer s.mutex.RUnlock()

	items := make([]*models.Item, 0, len(s.items))
	for _, item := range s.items {
		items = append(items, item)
	}

	span.SetAttributes(attribute.Int("items.count", len(items)))
	return items, nil
}

// Update modifies an existing item
func (s *MemoryStorage) Update(ctx context.Context, id string, name, description string) (*models.Item, error) {
	ctx, span := tracer.Start(ctx, "storage.update_item")
	defer span.End()

	span.SetAttributes(
		attribute.String("item.id", id),
		attribute.String("item.new_name", name),
	)

	s.mutex.Lock()
	defer s.mutex.Unlock()

	item, exists := s.items[id]
	if !exists {
		span.SetAttributes(attribute.Bool("item.found", false))
		span.RecordError(ErrItemNotFound)
		return nil, ErrItemNotFound
	}

	oldName := item.Name
	item.Update(name, description)
	
	span.SetAttributes(
		attribute.Bool("item.found", true),
		attribute.String("item.old_name", oldName),
		attribute.String("item.updated_name", item.Name),
	)
	
	return item, nil
}

// Delete removes an item by its ID
func (s *MemoryStorage) Delete(ctx context.Context, id string) error {
	ctx, span := tracer.Start(ctx, "storage.delete_item")
	defer span.End()

	span.SetAttributes(attribute.String("item.id", id))

	s.mutex.Lock()
	defer s.mutex.Unlock()

	item, exists := s.items[id]
	if !exists {
		span.SetAttributes(attribute.Bool("item.found", false))
		span.RecordError(ErrItemNotFound)
		return ErrItemNotFound
	}

	delete(s.items, id)
	
	span.SetAttributes(
		attribute.Bool("item.found", true),
		attribute.String("item.deleted_name", item.Name),
		attribute.Int("storage.remaining_items", len(s.items)),
	)
	
	return nil
}

// Count returns the total number of items
func (s *MemoryStorage) Count(ctx context.Context) (int, error) {
	ctx, span := tracer.Start(ctx, "storage.count_items")
	defer span.End()

	s.mutex.RLock()
	defer s.mutex.RUnlock()

	count := len(s.items)
	span.SetAttributes(attribute.Int("items.count", count))
	
	return count, nil
}
