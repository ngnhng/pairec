# Quick Start Guide

This guide will get you up and running with PaiRec in under 5 minutes.

## Prerequisites
- Go 1.20 or later
- Git (for cloning)

## 1-Minute Setup

```bash
# Clone and setup
git clone https://github.com/alibaba/pairec.git
cd pairec
./setup.sh

# Start the server
./pairec -config examples/basic-config.json
```

The server will start on `http://localhost:8000`.

## Test the API

In another terminal:
```bash
./test-api.sh
```

Or manually:
```bash
# Health check
curl http://localhost:8000/ping

# Get recommendations
curl -X POST http://localhost:8000/api/recommend \
  -H "Content-Type: application/json" \
  -d '{
    "scene_id": "homepage",
    "uid": "user123", 
    "size": 10
  }'
```

## Request Flow Visualization

```
User Request → Web API → Service Layer → Processing → Data Layer → Response

1. HTTP Request     │ POST /api/recommend
   ↓                │ {"scene_id": "homepage", "uid": "user123"}
                    │
2. Controller       │ Parse & validate request parameters
   ↓                │ Create RecommendContext
                    │
3. Service Layer    │ Load user profile & preferences  
   ↓                │ Initialize recommendation pipeline
                    │
4. Recall Phase     │ Generate candidate items from multiple sources:
   ↓                │ • Collaborative filtering
                    │ • Content-based matching
                    │ • Popular items
                    │
5. Filter Phase     │ Apply business rules:
   ↓                │ • Quality filters
                    │ • Diversity constraints
                    │ • Availability checks
                    │
6. Rank Phase       │ Score items using ML models:
   ↓                │ • Feature extraction
                    │ • Model prediction
                    │ • Score normalization
                    │
7. Sort Phase       │ Final ordering:
   ↓                │ • Sort by relevance score
                    │ • Apply business boosts
                    │ • Ensure diversity
                    │
8. HTTP Response    │ Return JSON with recommended items
```

## Configuration Explained

PaiRec uses JSON configuration to define behavior:

```json
{
  "scene_confs": [{
    "scene_id": "homepage",           // Scene identifier
    "recall_names": ["cf", "cb"],     // Which recall algorithms to use
    "filter_names": ["quality"],      // Which filters to apply  
    "sort_names": ["ml_rank"],        // How to sort final results
    "conf": {
      "recall_count": 1000,           // How many items to recall
      "final_count": 50               // How many to return
    }
  }]
}
```

## Next Steps

1. **Read the docs**: Start with [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)
2. **Explore examples**: Check out `examples/` directory
3. **Try advanced features**: Configure algorithms, filters, and data sources
4. **Contribute**: See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines

## Common Issues

**Build fails?**
- Ensure Go 1.20+ is installed
- Run `go mod tidy` to update dependencies

**Server won't start?**  
- Check if port 8000 is available
- Verify configuration file syntax
- Check logs for error messages

**API returns errors?**
- Ensure server is running
- Check request format matches examples
- Use `"debug": true` for detailed error info

## Getting Help

- 📖 **Documentation**: All `.md` files in this repository
- 🐛 **Issues**: [GitHub Issues](https://github.com/alibaba/pairec/issues)
- 💬 **Discussions**: GitHub Discussions for questions
- 📝 **Examples**: `examples/` directory for configuration samples

Ready to build amazing recommendation systems? Let's go! 🚀