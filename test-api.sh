#!/bin/bash

# PaiRec API Testing Script
# This script demonstrates how to test the PaiRec API endpoints

set -e

PAIREC_HOST="${PAIREC_HOST:-localhost:8000}"

echo "🚀 Testing PaiRec API endpoints at http://${PAIREC_HOST}"
echo ""

# Test health endpoint
echo "1. Testing health endpoint..."
response=$(curl -s "http://${PAIREC_HOST}/ping" || echo "FAILED")
if [ "$response" = "success" ]; then
    echo "✅ Health check: OK"
else
    echo "❌ Health check: FAILED - $response"
    echo "Make sure PaiRec is running with: go run . -config examples/basic-config.json"
    exit 1
fi
echo ""

# Test route discovery
echo "2. Discovering available routes..."
routes=$(curl -s "http://${PAIREC_HOST}/route_paths" || echo "[]")
echo "✅ Available routes: $routes"
echo ""

# Test recommendation endpoint
echo "3. Testing recommendation endpoint..."
recommendation_response=$(curl -s -X POST "http://${PAIREC_HOST}/api/recommend" \
    -H "Content-Type: application/json" \
    -d '{
        "scene_id": "homepage",
        "uid": "test_user_123", 
        "size": 5,
        "debug": true
    }' || echo '{"error": "request failed"}')

if echo "$recommendation_response" | grep -q '"code"'; then
    echo "✅ Recommendation API: Response received"
    echo "   Response preview: $(echo "$recommendation_response" | head -c 200)..."
else
    echo "❌ Recommendation API: FAILED"
    echo "   Response: $recommendation_response"
fi
echo ""

# Test user recall endpoint
echo "4. Testing user recall endpoint..."
recall_response=$(curl -s -X POST "http://${PAIREC_HOST}/api/recall" \
    -H "Content-Type: application/json" \
    -d '{
        "scene_id": "homepage",
        "uid": "test_user_123",
        "size": 10
    }' || echo '{"error": "request failed"}')

if echo "$recall_response" | grep -q '"code"'; then
    echo "✅ User Recall API: Response received"
    echo "   Response preview: $(echo "$recall_response" | head -c 200)..."
else
    echo "❌ User Recall API: FAILED" 
    echo "   Response: $recall_response"
fi
echo ""

# Test feature reply endpoint
echo "5. Testing feature reply endpoint..."
feature_response=$(curl -s -X POST "http://${PAIREC_HOST}/api/feature_reply" \
    -H "Content-Type: application/json" \
    -d '{
        "user_ids": ["test_user_123"],
        "item_ids": ["item_001", "item_002"]
    }' || echo '{"error": "request failed"}')

if echo "$feature_response" | grep -q '"code"'; then
    echo "✅ Feature Reply API: Response received"
    echo "   Response preview: $(echo "$feature_response" | head -c 200)..."
else
    echo "❌ Feature Reply API: FAILED"
    echo "   Response: $feature_response" 
fi
echo ""

# Test callback endpoint
echo "6. Testing callback endpoint..."
callback_response=$(curl -s -X POST "http://${PAIREC_HOST}/api/callback" \
    -H "Content-Type: application/json" \
    -d '{
        "uid": "test_user_123",
        "item_id": "item_001", 
        "action": "click",
        "scene_id": "homepage"
    }' || echo '{"error": "request failed"}')

if echo "$callback_response" | grep -q '"code"' || echo "$callback_response" | grep -q '"success"'; then
    echo "✅ Callback API: Response received"
    echo "   Response preview: $(echo "$callback_response" | head -c 200)..."
else
    echo "❌ Callback API: FAILED"
    echo "   Response: $callback_response"
fi
echo ""

# Test metrics endpoints  
echo "7. Testing monitoring endpoints..."
metrics_available=$(curl -s "http://${PAIREC_HOST}/metrics" | head -n 5 | grep -c "^#" || echo "0")
if [ "$metrics_available" -gt 0 ]; then
    echo "✅ Metrics endpoint: Available ($metrics_available metric types found)"
else
    echo "❌ Metrics endpoint: Not available or no metrics found"
fi

custom_metrics_available=$(curl -s "http://${PAIREC_HOST}/custom_metrics" | head -n 5 | grep -c "^#" || echo "0")
if [ "$custom_metrics_available" -gt 0 ]; then
    echo "✅ Custom metrics endpoint: Available ($custom_metrics_available metric types found)"
else
    echo "⚠️  Custom metrics endpoint: Not available or no custom metrics found"
fi
echo ""

echo "🎉 API testing complete!"
echo ""
echo "📝 To run PaiRec server:"
echo "   go run . -config examples/basic-config.json"
echo ""
echo "📖 For more information, see:"
echo "   - API_REFERENCE.md for detailed API documentation"
echo "   - DEVELOPER_GUIDE.md for development setup"
echo "   - ARCHITECTURE.md for system overview"