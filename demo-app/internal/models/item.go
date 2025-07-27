package models

import (
	"time"

	"github.com/google/uuid"
)

// Item represents a simple item in our CRUD application
type Item struct {
	ID          string    `json:"id"`
	Name        string    `json:"name" binding:"required"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// NewItem creates a new item with generated ID and timestamps
func NewItem(name, description string) *Item {
	now := time.Now()
	return &Item{
		ID:          uuid.New().String(),
		Name:        name,
		Description: description,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
}

// Update updates the item's fields and timestamp
func (i *Item) Update(name, description string) {
	if name != "" {
		i.Name = name
	}
	if description != "" {
		i.Description = description
	}
	i.UpdatedAt = time.Now()
}
