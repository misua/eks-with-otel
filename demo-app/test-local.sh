#!/bin/bash

# Local Testing Script for EKS OpenTelemetry Demo App
# This script tests all CRUD endpoints locally

BASE_URL="http://localhost:8080"
ITEM_ID=""

echo "🚀 Testing EKS OpenTelemetry Demo App Locally"
echo "=============================================="

# Test 1: Health Check
echo "1. Testing Health Check..."
curl -s "$BASE_URL/health" | jq '.' || echo "Health check failed"
echo ""

# Test 2: Service Info
echo "2. Testing Service Info..."
curl -s "$BASE_URL/" | jq '.' || echo "Service info failed"
echo ""

# Test 3: Create Item
echo "3. Creating a new item..."
CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "Local Test Item", "description": "This is a test item created during local testing"}')

echo "$CREATE_RESPONSE" | jq '.'
ITEM_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
echo "Created item with ID: $ITEM_ID"
echo ""

# Test 4: List All Items
echo "4. Listing all items..."
curl -s "$BASE_URL/api/v1/items" | jq '.'
echo ""

# Test 5: Get Specific Item
if [ "$ITEM_ID" != "null" ] && [ "$ITEM_ID" != "" ]; then
    echo "5. Getting specific item ($ITEM_ID)..."
    curl -s "$BASE_URL/api/v1/items/$ITEM_ID" | jq '.'
    echo ""

    # Test 6: Update Item
    echo "6. Updating item ($ITEM_ID)..."
    curl -s -X PUT "$BASE_URL/api/v1/items/$ITEM_ID" \
      -H "Content-Type: application/json" \
      -d '{"name": "Updated Local Test Item", "description": "This item has been updated during local testing"}' | jq '.'
    echo ""

    # Test 7: Get Updated Item
    echo "7. Getting updated item ($ITEM_ID)..."
    curl -s "$BASE_URL/api/v1/items/$ITEM_ID" | jq '.'
    echo ""

    # Test 8: Delete Item
    echo "8. Deleting item ($ITEM_ID)..."
    curl -s -X DELETE "$BASE_URL/api/v1/items/$ITEM_ID" | jq '.'
    echo ""

    # Test 9: Verify Deletion
    echo "9. Verifying item deletion ($ITEM_ID)..."
    curl -s "$BASE_URL/api/v1/items/$ITEM_ID" | jq '.'
    echo ""
else
    echo "❌ Could not extract item ID from create response. Skipping remaining tests."
fi

# Test 10: Final List (should be empty or without our test item)
echo "10. Final items list..."
curl -s "$BASE_URL/api/v1/items" | jq '.'
echo ""

echo "✅ Local testing completed!"
echo ""
echo "📊 Check the application logs to see:"
echo "   - Structured JSON logs with trace correlation"
echo "   - OpenTelemetry spans for each operation"
echo "   - HTTP request/response logging"
