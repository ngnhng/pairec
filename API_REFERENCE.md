# API Reference

This document provides comprehensive documentation for PaiRec's HTTP API endpoints, including request/response formats, parameters, and usage examples.

## Table of Contents
- [Authentication](#authentication)
- [Common Headers](#common-headers)
- [Response Format](#response-format)
- [Endpoints](#endpoints)
  - [Recommendation API](#recommendation-api)
  - [User Recall API](#user-recall-api)
  - [Feature Reply API](#feature-reply-api)
  - [Embedding API](#embedding-api)
  - [Callback API](#callback-api)
  - [Health & Monitoring](#health--monitoring)

## Authentication

Currently, PaiRec does not enforce authentication by default. Authentication can be implemented through middleware if required.

## Common Headers

All API requests should include:

```http
Content-Type: application/json
Accept: application/json
```

## Response Format

All API responses follow a consistent JSON format:

### Success Response
```json
{
  "code": 200,
  "message": "success",
  "data": {
    // Response data specific to endpoint
  },
  "request_id": "unique-request-identifier"
}
```

### Error Response
```json
{
  "code": 400,
  "message": "Error description",
  "request_id": "unique-request-identifier"
}
```

## Endpoints

### Recommendation API

**GET/POST** `/api/recommend`

The main endpoint for getting personalized recommendations.

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `scene_id` | string | Yes | Scene identifier for the recommendation context |
| `uid` | string | Yes | User identifier |
| `size` | integer | No | Number of recommended items to return (default: 10) |
| `category` | string | No | Category filter (default: "default") |
| `debug` | boolean | No | Enable debug mode for detailed logs (default: false) |
| `features` | object | No | Additional features for the recommendation |

#### Request Example
```bash
curl -X POST http://localhost:8000/api/recommend \
  -H "Content-Type: application/json" \
  -d '{
    "scene_id": "home_page",
    "uid": "user_12345",
    "size": 20,
    "category": "electronics",
    "debug": false,
    "features": {
      "user_age": 25,
      "user_gender": "male",
      "device": "mobile"
    }
  }'
```

#### Response Example
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "item_id": "item_001",
        "score": 0.95,
        "item_type": "product",
        "categories": ["electronics", "smartphones"],
        "properties": {
          "title": "Latest Smartphone",
          "price": 699.99,
          "brand": "TechBrand"
        }
      },
      {
        "item_id": "item_002", 
        "score": 0.87,
        "item_type": "product",
        "categories": ["electronics", "laptops"],
        "properties": {
          "title": "Gaming Laptop",
          "price": 1299.99,
          "brand": "GameTech"
        }
      }
    ],
    "total": 2,
    "scene_id": "home_page",
    "request_id": "req_20241122_001"
  }
}
```

#### Debug Mode Response
When `debug: true`, additional information is included:

```json
{
  "code": 200,
  "message": "success", 
  "data": {
    "items": [...],
    "debug_info": {
      "recall_info": {
        "total_recalled": 1000,
        "sources": ["collaborative_filtering", "content_based"],
        "timing": {
          "collaborative_filtering": "12ms",
          "content_based": "8ms"
        }
      },
      "filter_info": {
        "initial_count": 1000,
        "after_quality_filter": 800,
        "after_diversity_filter": 500,
        "final_count": 20
      },
      "rank_info": {
        "algorithm": "dnn_ranking",
        "model_version": "v1.2.3",
        "timing": "45ms"
      }
    }
  }
}
```

### User Recall API

**GET/POST** `/api/recall`

Retrieves candidate items for a user without ranking.

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `scene_id` | string | Yes | Scene identifier |
| `uid` | string | Yes | User identifier |
| `size` | integer | No | Number of items to recall (default: 100) |
| `recall_type` | string | No | Specific recall algorithm to use |

#### Request Example
```bash
curl -X POST http://localhost:8000/api/recall \
  -H "Content-Type: application/json" \
  -d '{
    "scene_id": "home_page",
    "uid": "user_12345",
    "size": 50,
    "recall_type": "collaborative_filtering"
  }'
```

#### Response Example
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "item_id": "item_001",
        "recall_score": 0.85,
        "recall_source": "collaborative_filtering"
      },
      {
        "item_id": "item_002",
        "recall_score": 0.78,
        "recall_source": "content_based"
      }
    ],
    "total": 2,
    "recall_sources": ["collaborative_filtering", "content_based"]
  }
}
```

### Feature Reply API

**POST** `/api/feature_reply`

Processes and extracts features for given users and items.

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `user_ids` | array | Yes | List of user identifiers |
| `item_ids` | array | Yes | List of item identifiers |
| `feature_names` | array | No | Specific features to extract |

#### Request Example
```bash
curl -X POST http://localhost:8000/api/feature_reply \
  -H "Content-Type: application/json" \
  -d '{
    "user_ids": ["user_12345", "user_67890"],
    "item_ids": ["item_001", "item_002"],
    "feature_names": ["user_profile", "item_content", "interaction_history"]
  }'
```

#### Response Example
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "user_features": {
      "user_12345": {
        "user_profile": {
          "age": 25,
          "gender": "male",
          "location": "beijing"
        },
        "interaction_history": {
          "click_count": 150,
          "purchase_count": 12
        }
      }
    },
    "item_features": {
      "item_001": {
        "item_content": {
          "category": "electronics",
          "brand": "TechBrand",
          "price": 699.99
        }
      }
    }
  }
}
```

### Embedding API

**POST** `/api/embedding`

Generates vector embeddings for users or items.

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | Type of embedding: "user" or "item" |
| `ids` | array | Yes | List of user or item identifiers |
| `embedding_model` | string | No | Specific embedding model to use |

#### Request Example
```bash
curl -X POST http://localhost:8000/api/embedding \
  -H "Content-Type: application/json" \
  -d '{
    "type": "user",
    "ids": ["user_12345", "user_67890"],
    "embedding_model": "dssm"
  }'
```

#### Response Example
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "embeddings": {
      "user_12345": [0.1, 0.2, -0.3, 0.8, ..., 0.15],
      "user_67890": [0.3, -0.1, 0.7, -0.2, ..., 0.42]
    },
    "dimension": 128,
    "model": "dssm"
  }
}
```

### Callback API

**POST** `/api/callback`

Logs user interactions and feedback for model training and optimization.

#### Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `uid` | string | Yes | User identifier |
| `item_id` | string | Yes | Item identifier |
| `action` | string | Yes | Action type: "click", "view", "purchase", etc. |
| `scene_id` | string | Yes | Scene where action occurred |
| `timestamp` | integer | No | Unix timestamp (default: current time) |
| `properties` | object | No | Additional action properties |

#### Request Example
```bash
curl -X POST http://localhost:8000/api/callback \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "user_12345",
    "item_id": "item_001",
    "action": "click",
    "scene_id": "home_page",
    "timestamp": 1642680000,
    "properties": {
      "position": 1,
      "source": "recommendation",
      "device": "mobile"
    }
  }'
```

#### Response Example
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "logged": true,
    "callback_id": "cb_20241122_001"
  }
}
```

## Health & Monitoring

### Health Check

**GET** `/ping`

Basic health check endpoint.

#### Response Example
```
success
```

### Available Routes

**GET** `/route_paths`

Returns list of available API endpoints.

#### Response Example
```json
[
  "/api/recommend",
  "/api/recall", 
  "/api/callback",
  "/api/feature_reply",
  "/api/embedding"
]
```

### Metrics

**GET** `/metrics`

Prometheus metrics endpoint for monitoring.

#### Response Example
```
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 0
go_gc_duration_seconds{quantile="0.25"} 0
...

# HELP pairec_recommend_requests_total Total number of recommend requests
# TYPE pairec_recommend_requests_total counter
pairec_recommend_requests_total{scene="home_page"} 1234
...
```

### Custom Metrics

**GET** `/custom_metrics`

Application-specific metrics endpoint.

#### Response Example
```
# HELP pairec_recall_latency_seconds Recall operation latency
# TYPE pairec_recall_latency_seconds histogram
pairec_recall_latency_seconds_bucket{algorithm="collaborative_filtering",le="0.01"} 100
...
```

## Error Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad Request - Invalid parameters |
| 404 | Not Found - Scene or configuration not found |
| 500 | Internal Server Error - Processing error |
| 503 | Service Unavailable - Dependency service error |

## Rate Limiting

Currently, no rate limiting is implemented by default. It can be added through middleware configuration.

## SDK Usage Examples

### Go Client Example
```go
package main

import (
    "bytes"
    "encoding/json"
    "net/http"
)

type RecommendRequest struct {
    SceneId  string `json:"scene_id"`
    Uid      string `json:"uid"`
    Size     int    `json:"size"`
}

func getRecommendations(sceneId, uid string, size int) error {
    req := RecommendRequest{
        SceneId: sceneId,
        Uid:     uid,
        Size:    size,
    }
    
    data, _ := json.Marshal(req)
    resp, err := http.Post("http://localhost:8000/api/recommend", 
                          "application/json", 
                          bytes.NewBuffer(data))
    if err != nil {
        return err
    }
    defer resp.Body.Close()
    
    // Process response
    return nil
}
```

### Python Client Example
```python
import requests
import json

def get_recommendations(scene_id, uid, size=10):
    url = "http://localhost:8000/api/recommend"
    payload = {
        "scene_id": scene_id,
        "uid": uid,  
        "size": size
    }
    
    response = requests.post(url, json=payload)
    return response.json()

# Usage
result = get_recommendations("home_page", "user_12345", 20)
print(json.dumps(result, indent=2))
```

### JavaScript Client Example
```javascript
async function getRecommendations(sceneId, uid, size = 10) {
    const response = await fetch('http://localhost:8000/api/recommend', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            scene_id: sceneId,
            uid: uid,
            size: size
        })
    });
    
    return await response.json();
}

// Usage
getRecommendations('home_page', 'user_12345', 20)
    .then(result => console.log(result))
    .catch(error => console.error(error));
```

## Configuration Examples

### Scene Configuration
```json
{
  "scene_confs": [
    {
      "scene_id": "home_page",
      "recall_names": ["collaborative_filtering", "content_based"],
      "filter_names": ["quality_filter", "diversity_filter"],
      "sort_names": ["ml_ranking", "business_boost"],
      "conf": {
        "recall_count": 1000,
        "final_count": 50
      }
    }
  ]
}
```

This API reference provides comprehensive documentation for integrating with PaiRec services. For advanced configuration and customization, refer to the [Architecture Documentation](ARCHITECTURE.md) and [Developer Guide](DEVELOPER_GUIDE.md).