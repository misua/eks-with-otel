package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const (
	defaultBaseURL = "http://localhost:8080"
	defaultDuration = 5 * time.Minute
	defaultConcurrency = 3
)

type Item struct {
	ID          string    `json:"id,omitempty"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at,omitempty"`
	UpdatedAt   time.Time `json:"updated_at,omitempty"`
}

type ItemsResponse struct {
	Items []Item `json:"items"`
	Total int    `json:"total"`
}

type LoadGenerator struct {
	baseURL    string
	client     *http.Client
	itemIDs    []string
	stats      *Stats
}

type Stats struct {
	TotalRequests   int
	SuccessRequests int
	FailedRequests  int
	CreateCount     int
	ReadCount       int
	UpdateCount     int
	DeleteCount     int
	HealthCount     int
}

func main() {
	baseURL := getEnv("DEMO_APP_URL", defaultBaseURL)
	duration := parseDuration(getEnv("LOAD_DURATION", "5m"))
	concurrency := parseInt(getEnv("CONCURRENCY", "3"))

	fmt.Printf("🚀 Starting Load Generator for EKS OpenTelemetry Demo\n")
	fmt.Printf("====================================================\n")
	fmt.Printf("Target URL: %s\n", baseURL)
	fmt.Printf("Duration: %v\n", duration)
	fmt.Printf("Concurrency: %d\n", concurrency)
	fmt.Printf("====================================================\n\n")

	// Create load generator
	lg := &LoadGenerator{
		baseURL: baseURL,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
		itemIDs: make([]string, 0),
		stats:   &Stats{},
	}

	// Wait for app to be ready
	if !lg.waitForApp() {
		log.Fatal("❌ Demo app is not responding. Make sure it's running.")
	}

	// Setup graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// Start load generation
	done := make(chan bool)
	go lg.generateLoad(duration, concurrency, done)

	// Start stats reporting
	go lg.reportStats()

	// Wait for completion or interrupt
	select {
	case <-done:
		fmt.Println("\n✅ Load generation completed successfully!")
	case <-quit:
		fmt.Println("\n🛑 Load generation interrupted by user")
	}

	lg.printFinalStats()
}

func (lg *LoadGenerator) waitForApp() bool {
	fmt.Print("⏳ Waiting for demo app to be ready...")
	for i := 0; i < 30; i++ {
		resp, err := lg.client.Get(lg.baseURL + "/health")
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			fmt.Println(" ✅ Ready!")
			return true
		}
		if resp != nil {
			resp.Body.Close()
		}
		fmt.Print(".")
		time.Sleep(2 * time.Second)
	}
	fmt.Println(" ❌ Failed!")
	return false
}

func (lg *LoadGenerator) generateLoad(duration time.Duration, concurrency int, done chan bool) {
	endTime := time.Now().Add(duration)
	
	// Start worker goroutines
	for i := 0; i < concurrency; i++ {
		go lg.worker(i, endTime)
	}

	// Wait for duration
	time.Sleep(duration)
	done <- true
}

func (lg *LoadGenerator) worker(workerID int, endTime time.Time) {
	fmt.Printf("🔧 Worker %d started\n", workerID)
	
	for time.Now().Before(endTime) {
		// Randomly choose an operation
		operation := lg.chooseOperation()
		
		switch operation {
		case "health":
			lg.doHealthCheck()
		case "create":
			lg.doCreateItem()
		case "list":
			lg.doListItems()
		case "get":
			lg.doGetItem()
		case "update":
			lg.doUpdateItem()
		case "delete":
			lg.doDeleteItem()
		}
		
		// Random delay between requests (100ms to 2s)
		delay := time.Duration(rand.Intn(1900)+100) * time.Millisecond
		time.Sleep(delay)
	}
	
	fmt.Printf("🏁 Worker %d finished\n", workerID)
}

func (lg *LoadGenerator) chooseOperation() string {
	// Weighted random selection to create realistic traffic patterns
	operations := []string{
		"health", "health", "health",  // 30% health checks
		"create", "create",            // 20% creates
		"list", "list", "list",        // 30% list operations
		"get", "get",                  // 20% get operations
		"update",                      // 10% updates
		"delete",                      // 10% deletes (but only if we have items)
	}
	
	// Don't delete if we have no items
	if len(lg.itemIDs) == 0 {
		operations = append(operations[:len(operations)-1], "create")
	}
	
	return operations[rand.Intn(len(operations))]
}

func (lg *LoadGenerator) doHealthCheck() {
	lg.stats.TotalRequests++
	lg.stats.HealthCount++
	
	resp, err := lg.client.Get(lg.baseURL + "/health")
	if err != nil {
		lg.stats.FailedRequests++
		fmt.Printf("❌ Health check failed: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 200 {
		lg.stats.SuccessRequests++
		fmt.Printf("✅ Health check OK\n")
	} else {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  Health check returned %d\n", resp.StatusCode)
	}
}

func (lg *LoadGenerator) doCreateItem() {
	lg.stats.TotalRequests++
	lg.stats.CreateCount++
	
	// Generate random item data
	item := Item{
		Name:        fmt.Sprintf("Load Test Item %d", rand.Intn(10000)),
		Description: fmt.Sprintf("Generated by load test at %s", time.Now().Format("15:04:05")),
	}
	
	jsonData, _ := json.Marshal(item)
	resp, err := lg.client.Post(lg.baseURL+"/api/v1/items", "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		lg.stats.FailedRequests++
		fmt.Printf("❌ Create item failed: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 201 {
		lg.stats.SuccessRequests++
		
		// Parse response to get item ID
		var createdItem Item
		body, _ := io.ReadAll(resp.Body)
		if json.Unmarshal(body, &createdItem) == nil {
			lg.itemIDs = append(lg.itemIDs, createdItem.ID)
			fmt.Printf("✅ Created item: %s\n", createdItem.Name)
		}
	} else {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  Create item returned %d\n", resp.StatusCode)
	}
}

func (lg *LoadGenerator) doListItems() {
	lg.stats.TotalRequests++
	lg.stats.ReadCount++
	
	resp, err := lg.client.Get(lg.baseURL + "/api/v1/items")
	if err != nil {
		lg.stats.FailedRequests++
		fmt.Printf("❌ List items failed: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 200 {
		lg.stats.SuccessRequests++
		
		// Parse response to update our item IDs
		var itemsResp ItemsResponse
		body, _ := io.ReadAll(resp.Body)
		if json.Unmarshal(body, &itemsResp) == nil {
			// Update our item IDs list
			lg.itemIDs = make([]string, 0, len(itemsResp.Items))
			for _, item := range itemsResp.Items {
				lg.itemIDs = append(lg.itemIDs, item.ID)
			}
			fmt.Printf("✅ Listed %d items\n", itemsResp.Total)
		}
	} else {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  List items returned %d\n", resp.StatusCode)
	}
}

func (lg *LoadGenerator) doGetItem() {
	if len(lg.itemIDs) == 0 {
		// No items to get, create one first
		lg.doCreateItem()
		return
	}
	
	lg.stats.TotalRequests++
	lg.stats.ReadCount++
	
	// Get random item
	itemID := lg.itemIDs[rand.Intn(len(lg.itemIDs))]
	
	resp, err := lg.client.Get(lg.baseURL + "/api/v1/items/" + itemID)
	if err != nil {
		lg.stats.FailedRequests++
		fmt.Printf("❌ Get item failed: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 200 {
		lg.stats.SuccessRequests++
		fmt.Printf("✅ Retrieved item: %s\n", itemID[:8]+"...")
	} else if resp.StatusCode == 404 {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  Item not found: %s\n", itemID[:8]+"...")
		// Remove from our list
		lg.removeItemID(itemID)
	} else {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  Get item returned %d\n", resp.StatusCode)
	}
}

func (lg *LoadGenerator) doUpdateItem() {
	if len(lg.itemIDs) == 0 {
		// No items to update, create one first
		lg.doCreateItem()
		return
	}
	
	lg.stats.TotalRequests++
	lg.stats.UpdateCount++
	
	// Get random item
	itemID := lg.itemIDs[rand.Intn(len(lg.itemIDs))]
	
	// Generate updated data
	item := Item{
		Name:        fmt.Sprintf("Updated Item %d", rand.Intn(10000)),
		Description: fmt.Sprintf("Updated by load test at %s", time.Now().Format("15:04:05")),
	}
	
	jsonData, _ := json.Marshal(item)
	req, _ := http.NewRequest("PUT", lg.baseURL+"/api/v1/items/"+itemID, bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	
	resp, err := lg.client.Do(req)
	if err != nil {
		lg.stats.FailedRequests++
		fmt.Printf("❌ Update item failed: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 200 {
		lg.stats.SuccessRequests++
		fmt.Printf("✅ Updated item: %s\n", itemID[:8]+"...")
	} else if resp.StatusCode == 404 {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  Item not found for update: %s\n", itemID[:8]+"...")
		lg.removeItemID(itemID)
	} else {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  Update item returned %d\n", resp.StatusCode)
	}
}

func (lg *LoadGenerator) doDeleteItem() {
	if len(lg.itemIDs) == 0 {
		// No items to delete, create one first
		lg.doCreateItem()
		return
	}
	
	lg.stats.TotalRequests++
	lg.stats.DeleteCount++
	
	// Get random item
	itemID := lg.itemIDs[rand.Intn(len(lg.itemIDs))]
	
	req, _ := http.NewRequest("DELETE", lg.baseURL+"/api/v1/items/"+itemID, nil)
	resp, err := lg.client.Do(req)
	if err != nil {
		lg.stats.FailedRequests++
		fmt.Printf("❌ Delete item failed: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 200 {
		lg.stats.SuccessRequests++
		fmt.Printf("✅ Deleted item: %s\n", itemID[:8]+"...")
		lg.removeItemID(itemID)
	} else if resp.StatusCode == 404 {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  Item not found for delete: %s\n", itemID[:8]+"...")
		lg.removeItemID(itemID)
	} else {
		lg.stats.FailedRequests++
		fmt.Printf("⚠️  Delete item returned %d\n", resp.StatusCode)
	}
}

func (lg *LoadGenerator) removeItemID(itemID string) {
	for i, id := range lg.itemIDs {
		if id == itemID {
			lg.itemIDs = append(lg.itemIDs[:i], lg.itemIDs[i+1:]...)
			break
		}
	}
}

func (lg *LoadGenerator) reportStats() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	
	for range ticker.C {
		fmt.Printf("\n📊 Stats Update:\n")
		fmt.Printf("   Total Requests: %d\n", lg.stats.TotalRequests)
		fmt.Printf("   Success: %d, Failed: %d\n", lg.stats.SuccessRequests, lg.stats.FailedRequests)
		fmt.Printf("   Creates: %d, Reads: %d, Updates: %d, Deletes: %d, Health: %d\n",
			lg.stats.CreateCount, lg.stats.ReadCount, lg.stats.UpdateCount, lg.stats.DeleteCount, lg.stats.HealthCount)
		fmt.Printf("   Active Items: %d\n\n", len(lg.itemIDs))
	}
}

func (lg *LoadGenerator) printFinalStats() {
	fmt.Printf("\n📊 Final Statistics:\n")
	fmt.Printf("===================\n")
	fmt.Printf("Total Requests: %d\n", lg.stats.TotalRequests)
	fmt.Printf("Successful: %d (%.1f%%)\n", lg.stats.SuccessRequests, 
		float64(lg.stats.SuccessRequests)/float64(lg.stats.TotalRequests)*100)
	fmt.Printf("Failed: %d (%.1f%%)\n", lg.stats.FailedRequests,
		float64(lg.stats.FailedRequests)/float64(lg.stats.TotalRequests)*100)
	fmt.Printf("\nOperation Breakdown:\n")
	fmt.Printf("  Creates: %d\n", lg.stats.CreateCount)
	fmt.Printf("  Reads: %d\n", lg.stats.ReadCount)
	fmt.Printf("  Updates: %d\n", lg.stats.UpdateCount)
	fmt.Printf("  Deletes: %d\n", lg.stats.DeleteCount)
	fmt.Printf("  Health Checks: %d\n", lg.stats.HealthCount)
	fmt.Printf("\nItems remaining: %d\n", len(lg.itemIDs))
	fmt.Printf("\n🎯 Check your observability stack:\n")
	fmt.Printf("   - Traces in Tempo/Grafana\n")
	fmt.Printf("   - Logs in Loki/Grafana\n")
	fmt.Printf("   - Metrics in Prometheus/Grafana\n")
}

// Helper functions
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}

func parseDuration(s string) time.Duration {
	d, err := time.ParseDuration(s)
	if err != nil {
		return defaultDuration
	}
	return d
}

func parseInt(s string) int {
	if s == "" {
		return defaultConcurrency
	}
	var i int
	fmt.Sscanf(s, "%d", &i)
	if i <= 0 {
		return defaultConcurrency
	}
	return i
}
