# PaiRec Configuration Examples

This directory contains example configurations to help you get started with PaiRec in different scenarios.

## Basic Examples

### 1. Minimal Configuration (`basic-config.json`)
A minimal setup for testing and development.

### 2. E-commerce Configuration (`ecommerce-config.json`) 
A realistic e-commerce recommendation setup with multiple recall methods and business filters.

### 3. Content Platform Configuration (`content-config.json`)
Configuration for news, articles, or video recommendation platforms.

## Usage

```bash
# Run with basic configuration
go run . -config examples/basic-config.json

# Run with e-commerce configuration  
go run . -config examples/ecommerce-config.json

# Test the API
curl -X POST http://localhost:8000/api/recommend \
  -H "Content-Type: application/json" \
  -d '{"scene_id": "homepage", "uid": "user123", "size": 10}'
```

## Configuration Structure

All PaiRec configurations follow this general structure:

```json
{
  "listen_conf": {
    "http_port": 8000,
    "http_addr": "0.0.0.0"
  },
  "scene_confs": [
    {
      "scene_id": "scene_name",
      "recall_names": ["recall_algorithm_1", "recall_algorithm_2"],
      "filter_names": ["filter_1", "filter_2"],
      "sort_names": ["sort_algorithm"],
      "conf": {
        "recall_count": 1000,
        "final_count": 50
      }
    }
  ],
  "dao_conf": {
    // Database and storage configurations
  },
  "algo_confs": [
    // Algorithm configurations
  ]
}
```

For detailed configuration options, see the [Developer Guide](../DEVELOPER_GUIDE.md).