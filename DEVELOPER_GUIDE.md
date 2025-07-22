# Developer Guide

This guide will help you quickly get started with PaiRec development, understand the codebase, and contribute effectively to the project.

## Table of Contents
- [Quick Start](#quick-start)
- [Development Environment](#development-environment)
- [Project Structure](#project-structure)
- [Key Concepts](#key-concepts)
- [Building and Testing](#building-and-testing)
- [Development Workflow](#development-workflow)
- [Debugging](#debugging)
- [Common Tasks](#common-tasks)

## Quick Start

### Prerequisites
- Go 1.20 or later
- Git

### Installation
```bash
# Clone the repository
git clone https://github.com/alibaba/pairec.git
cd pairec

# Install dependencies
go mod tidy

# Build the project
go build .

# Run tests (optional - some may fail due to external dependencies)
go test ./... -v
```

### Running a Basic Server
```bash
# Create a minimal configuration file
cat > config.json << EOF
{
  "listen_conf": {
    "http_port": 8000,
    "http_addr": "0.0.0.0"
  },
  "scene_confs": [
    {
      "scene_id": "test_scene",
      "recall_names": [],
      "filter_names": [],
      "sort_names": []
    }
  ]
}
EOF

# Run the server
go run . -config config.json
```

The server will start on port 8000. You can test it:
```bash
curl http://localhost:8000/ping
# Should return: success
```

## Development Environment

### Recommended IDE Setup
- **VS Code** with Go extension
- **GoLand** by JetBrains
- **vim/neovim** with vim-go plugin

### Essential Go Tools
```bash
# Install useful Go tools
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/go-delve/delve/cmd/dlv@latest
```

### Environment Variables
Key environment variables for development:

- `CONFIG_NAME`: Use remote configuration (optional)
- `RUN_MODE`: Set to `daily` for development, `product` for production
- `LOG_LEVEL`: Control logging verbosity

## Project Structure

```
pairec/
├── algorithm/           # ML/AI model integrations
│   ├── eas/            # Alibaba Cloud EAS integration
│   ├── faiss/          # Facebook AI Similarity Search
│   ├── milvus/         # Vector database integration
│   └── tfserving/      # TensorFlow Serving
├── datasource/         # Data source connectors
│   ├── beengine/       # BE (Backend Engine) integration
│   ├── hbase/          # HBase connector
│   ├── kafka/          # Kafka integration
│   └── opensearch/     # OpenSearch connector
├── filter/             # Content filtering logic
├── persist/            # Data persistence layers
├── service/            # Core business logic
│   ├── fallback/       # Fallback mechanisms
│   ├── feature/        # Feature processing
│   ├── recall/         # Item recall services
│   └── rank/           # Ranking services
├── sort/               # Result sorting logic
├── web/                # HTTP controllers and APIs
├── recconf/            # Configuration management
├── context/            # Request context handling
└── utils/              # Utility functions
```

### Key Files
- `pairec.go`: Main application entry point
- `recconf/recconf.go`: Configuration structures
- `web/recommend_controller.go`: Main recommendation API
- `service/recommend.go`: Core recommendation logic

## Key Concepts

### 1. Recommendation Pipeline
Every recommendation request flows through these stages:
1. **Context Creation**: Parse request and create recommendation context
2. **Recall**: Generate candidate items from various sources
3. **Filter**: Apply business rules and constraints
4. **Rank**: Score items using ML models or algorithms
5. **Sort**: Final ordering and result preparation

### 2. Configuration-Driven Architecture
PaiRec is highly configurable. Most behavior is controlled through JSON configuration:

```json
{
  "scene_confs": [{
    "scene_id": "home_page",
    "recall_names": ["collaborative_filtering", "content_based"],
    "filter_names": ["quality_filter", "diversity_filter"],
    "sort_names": ["ml_ranking", "business_boost"]
  }]
}
```

### 3. Module System
Components are registered dynamically:
```go
// In your initialization code
func init() {
    service.RegisterRecall("my_recall", NewMyRecall)
    filter.RegisterFilter("my_filter", NewMyFilter)
}
```

### 4. Context Pattern
All operations receive a `RecommendContext`:
```go
type RecommendContext struct {
    RecommendId string                 // Unique request ID
    User        *module.User          // User information
    Scene       string                // Scene identifier
    Parameters  map[string]interface{} // Request parameters
}
```

## Building and Testing

### Building
```bash
# Build the main binary
go build .

# Build with race detection (for development)
go build -race .

# Build for different platforms
GOOS=linux GOARCH=amd64 go build .
```

### Testing
```bash
# Run all tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run tests for specific package
go test ./service/...

# Run tests with verbose output
go test -v ./service/feature/

# Run specific test
go test -run TestFeatureExtraction ./service/feature/
```

### Linting
```bash
# Run golangci-lint
golangci-lint run

# Fix auto-fixable issues
golangci-lint run --fix
```

## Development Workflow

### 1. Creating a New Feature
1. **Create a feature branch**:
   ```bash
   git checkout -b feature/my-new-feature
   ```

2. **Understand the requirements**: Review the issue or specification

3. **Identify affected components**: Determine which modules need changes

4. **Write tests first** (TDD approach):
   ```go
   func TestMyNewFeature(t *testing.T) {
       // Test implementation
   }
   ```

5. **Implement the feature**: Make minimal, focused changes

6. **Test thoroughly**:
   ```bash
   go test ./...
   go build .
   ```

7. **Update documentation** if needed

### 2. Adding a New Data Source
```go
// 1. Create your data source in datasource/mynewsource/
package mynewsource

import "github.com/alibaba/pairec/v2/recconf"

type MyDataSource struct {
    config *Config
}

func (ds *MyDataSource) Load(conf *recconf.RecommendConfig) error {
    // Initialize your data source
    return nil
}

// 2. Register in main initialization
func init() {
    RegisterDataSource("mynewsource", NewMyDataSource)
}
```

### 3. Adding a New Algorithm
```go
// 1. Create algorithm in algorithm/myalgo/
package myalgo

type MyAlgorithm struct {
    config *Config
}

func (a *MyAlgorithm) Predict(ctx context.RecommendContext) ([]*module.Item, error) {
    // Your algorithm logic
    return items, nil
}

// 2. Register the algorithm
func init() {
    algorithm.RegisterAlgorithm("myalgo", NewMyAlgorithm)
}
```

## Debugging

### 1. Debug Logging
Enable verbose logging:
```go
import "github.com/alibaba/pairec/v2/log"

log.Info("Debug message with context", 
    "user_id", userId, 
    "scene", sceneName)
```

### 2. Using Delve Debugger
```bash
# Install delve
go install github.com/go-delve/delve/cmd/dlv@latest

# Debug the application
dlv debug . -- -config config.json

# In delve:
(dlv) break main.main
(dlv) continue
(dlv) print variable_name
```

### 3. HTTP Debugging
Use curl to test endpoints:
```bash
# Test recommendation API
curl -X POST http://localhost:8000/api/recommend \
  -H "Content-Type: application/json" \
  -d '{
    "scene_id": "test_scene",
    "uid": "test_user",
    "size": 10
  }'

# Test with debug mode
curl -X POST http://localhost:8000/api/recommend \
  -H "Content-Type: application/json" \
  -d '{
    "scene_id": "test_scene", 
    "uid": "test_user",
    "size": 10,
    "debug": true
  }'
```

### 4. Metrics and Monitoring
- Check `/metrics` endpoint for Prometheus metrics
- Check `/custom_metrics` for application-specific metrics
- Use `/route_paths` to see available endpoints

## Common Tasks

### Adding a New Filter
```go
// 1. Create filter in filter/myfilter/
package myfilter

func NewMyFilter(config map[string]interface{}) filter.Filter {
    return &MyFilter{config: config}
}

type MyFilter struct {
    config map[string]interface{}
}

func (f *MyFilter) Filter(filterData *filter.FilterData) error {
    items := filterData.Data.([]*module.Item)
    
    // Apply your filtering logic
    var filteredItems []*module.Item
    for _, item := range items {
        if f.shouldKeepItem(item) {
            filteredItems = append(filteredItems, item)
        }
    }
    
    filterData.Data = filteredItems
    return nil
}

// 2. Register in filter package
func init() {
    RegisterFilter("myfilter", NewMyFilter)
}
```

### Adding Configuration Options
```go
// 1. Add to recconf/recconf.go
type RecommendConfig struct {
    // ... existing fields ...
    MyNewConfig MyConfigStruct `json:"my_new_config"`
}

// 2. Use in your component
func (c *MyComponent) LoadConfig(config *recconf.RecommendConfig) {
    c.myConfig = config.MyNewConfig
}
```

### Testing with Mock Data
```go
func TestMyComponent(t *testing.T) {
    // Create test context
    ctx := &context.RecommendContext{
        RecommendId: "test-123",
        User: &module.User{Id: "test_user"},
        Scene: "test_scene",
    }
    
    // Create test items
    items := []*module.Item{
        {Id: "item1", Score: 0.8},
        {Id: "item2", Score: 0.6},
    }
    
    // Test your component
    result := myComponent.Process(ctx, items)
    
    // Assert results
    assert.Equal(t, 2, len(result))
}
```

## Performance Tips

1. **Use connection pooling** for database connections
2. **Cache frequently accessed data** in Redis
3. **Profile your code** using Go's built-in profiler:
   ```bash
   go test -cpuprofile=cpu.prof -memprofile=mem.prof
   go tool pprof cpu.prof
   ```
4. **Monitor metrics** regularly
5. **Use efficient data structures** for large datasets

## Next Steps

1. Read the [Architecture Overview](ARCHITECTURE.md) for system design details
2. Check the [API Reference](API_REFERENCE.md) for endpoint documentation
3. Review [Contributing Guidelines](CONTRIBUTING.md) before submitting code
4. Join our community discussions for questions and support

## Getting Help

- Check existing issues on GitHub
- Review the Chinese documentation for advanced topics
- Use debug mode in your requests for detailed logging
- Monitor application metrics for performance insights