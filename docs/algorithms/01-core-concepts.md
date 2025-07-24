# Core Concepts

This guide introduces the fundamental concepts and design patterns that power PaiRec's algorithm framework. Understanding these concepts is essential for effectively using and extending the system.

## Table of Contents
- [The Algorithm Abstraction](#the-algorithm-abstraction)
- [Algorithm Factory Pattern](#algorithm-factory-pattern)
- [Configuration-Driven Design](#configuration-driven-design)
- [Response Interface](#response-interface)
- [Type System](#type-system)
- [Key Design Principles](#key-design-principles)

## The Algorithm Abstraction

### What is an Algorithm?

In PaiRec, an **algorithm** is any component that takes input data and produces a scored output for recommendation purposes. This could be:

- A machine learning model that scores items
- A vector similarity search that finds similar items
- A simple lookup that retrieves pre-computed scores
- A complex ensemble that combines multiple signals

### The IAlgorithm Interface

Every algorithm in PaiRec implements the `IAlgorithm` interface:

```go
type IAlgorithm interface {
    Init(conf *recconf.AlgoConfig) error
    Run(algoData interface{}) (interface{}, error)
}
```

**📍 File Reference**: [`algorithm/algorithm.go:28-31`](../../algorithm/algorithm.go#L28-L31)

#### Init Method
- **Purpose**: Initialize the algorithm with configuration
- **Input**: `*recconf.AlgoConfig` containing algorithm-specific settings
- **Output**: `error` if initialization fails
- **When Called**: Once during system startup or configuration reload

#### Run Method  
- **Purpose**: Execute the algorithm on input data
- **Input**: `interface{}` - flexible input data (features, vectors, etc.)
- **Output**: `interface{}` - algorithm results (usually `[]AlgoResponse`)
- **When Called**: For each recommendation request

### Why This Design?

```go
// ✅ Benefits of the interface approach:

// 1. Polymorphism - treat all algorithms uniformly
var algo IAlgorithm
algo = faiss.NewFaissModel("similarity")  // Vector search
algo = eas.NewEasModel("ranking")         // ML model serving
// Same interface, different implementations

// 2. Testability - easy to mock for testing
type MockAlgorithm struct{}
func (m *MockAlgorithm) Init(conf *recconf.AlgoConfig) error { return nil }
func (m *MockAlgorithm) Run(data interface{}) (interface{}, error) { 
    return []response.AlgoResponse{&MockResponse{score: 0.8}}, nil 
}

// 3. Hot-swappable - change algorithms without code changes
// Just update configuration, no recompilation needed
```

## Algorithm Factory Pattern

### The AlgorithmFactory

The `AlgorithmFactory` manages the lifecycle of all algorithms in the system:

```go
type AlgorithmFactory struct {
    algorithms       map[string]IAlgorithm    // name -> algorithm instance
    requestDataFuncs map[string]RequestDataFunc // custom data processors
    mutex            sync.RWMutex             // thread-safe access
    algorithmSigns   map[string]string        // configuration signatures
}
```

**📍 File Reference**: [`algorithm/algorithm.go:33-38`](../../algorithm/algorithm.go#L33-L38)

### Key Responsibilities

#### 1. **Algorithm Registration**
```go
// Multiple ways to register algorithms:

// From configuration (most common)
factory.Init(config.AlgoConfs)

// Manual registration
factory.RegisterAlgorithm("my-algo", myAlgorithmInstance)

// With automatic reload detection
factory.AddAlgoWithSign(conf) // Only reloads if config changed
```

#### 2. **Instance Management**
```go
// Thread-safe algorithm access
result, err := factory.Run("algorithm-name", inputData)

// Hot reloading - no downtime when updating configs
// Factory detects config changes via MD5 signatures
```

#### 3. **Type-Based Instantiation**
```go
// Factory automatically creates the right algorithm type:
func (a *AlgorithmFactory) initAlgo(conf recconf.AlgoConfig) (IAlgorithm, error) {
    switch conf.Type {
    case "EAS":
        return eas.NewEasModel(conf.Name), nil
    case "FAISS":
        return faiss.NewFaissModel(conf.Name), nil
    case "LOOKUP":
        return NewLookupPolicy(), nil
    case "SELDON":
        return new(seldon.Model), nil
    case "TFSERVING":
        return tfserving.NewTFservingModel(conf.Name), nil
    }
}
```

**📍 File Reference**: [`algorithm/algorithm.go:69-105`](../../algorithm/algorithm.go#L69-L105)

### Factory Benefits

| Benefit | Description | Example |
|---------|-------------|---------|
| **Centralized Management** | Single point to manage all algorithms | `algorithm.Run(name, data)` |
| **Configuration-Driven** | Algorithms defined in JSON, not code | Add new algorithms without recompilation |
| **Thread Safety** | Concurrent request handling | Multiple goroutines can safely call `Run()` |
| **Hot Reloading** | Update algorithms without restart | Change ML model endpoint at runtime |
| **Type Safety** | Compile-time checking of algorithm types | Catch misconfigurations early |

## Configuration-Driven Design

### Why Configuration-Driven?

PaiRec's algorithms are **configured, not coded**. This means:

```json
{
  "algo_confs": [
    {
      "name": "user-similarity",
      "type": "FAISS",
      "vector_conf": {
        "server_address": "localhost:8080",
        "timeout": 100
      }
    },
    {
      "name": "item-ranking", 
      "type": "EAS",
      "eas_conf": {
        "url": "https://ml-endpoint.com/predict",
        "processor": "TensorFlow",
        "timeout": 500
      }
    }
  ]
}
```

### Configuration Types

Each algorithm type has its own configuration structure:

```go
type AlgoConfig struct {
    Name       string        `json:"name"`
    Type       string        `json:"type"`        // "EAS", "FAISS", etc.
    
    // Type-specific configurations
    EasConf    EasConfig     `json:"eas_conf"`
    VectorConf VectorConfig  `json:"vector_conf"` 
    LookupConf LookupConfig  `json:"lookup_conf"`
    // ... other configs
}
```

### Benefits of Configuration-Driven Design

| Benefit | Traditional Code | PaiRec Configuration |
|---------|------------------|---------------------|
| **Deployment** | Recompile + restart | Update JSON config |
| **A/B Testing** | Multiple code branches | Multiple config files |
| **Environment** | Hardcoded values | Environment-specific configs |
| **Non-technical Users** | Need developers | Can modify configs directly |

## Response Interface

### Algorithm Responses

All algorithms return data that implements the `AlgoResponse` interface:

```go
type AlgoResponse interface {
    GetScore() float64                    // Main relevance score
    GetScoreMap() map[string]float64     // Multi-dimensional scores
    GetModuleType() bool                 // Algorithm type metadata
}
```

**📍 File Reference**: [`algorithm/response/response.go:3-7`](../../algorithm/response/response.go#L3-L7)

### Response Examples

```go
// Simple score response (LOOKUP algorithm)
type LookupResponse struct {
    score float64
}
func (r *LookupResponse) GetScore() float64 { return r.score }

// Complex ML response (EAS algorithm)  
type EasResponse struct {
    Score     float64
    ScoreMap  map[string]float64  // Multiple model outputs
    Features  map[string]float64  // Feature importance
}
func (r *EasResponse) GetScore() float64 { return r.Score }
func (r *EasResponse) GetScoreMap() map[string]float64 { return r.ScoreMap }
```

### Multi-Classification Support

For algorithms that return multiple classes:

```go
type AlgoMultiClassifyResponse interface {
    GetClassifyMap() map[string][]float64  // class -> probabilities
}
```

## Type System

### Supported Algorithm Types

| Type | Purpose | Example Use Case | Implementation |
|------|---------|------------------|----------------|
| **EAS** | Alibaba Cloud ML serving | Deep learning ranking models | [`algorithm/eas/`](../../algorithm/eas/) |
| **FAISS** | Vector similarity search | Content-based recommendations | [`algorithm/faiss/`](../../algorithm/faiss/) |
| **LOOKUP** | Simple score retrieval | Feature-based scoring | [`algorithm/lookup.go`](../../algorithm/lookup.go) |
| **MILVUS** | Vector database | Large-scale similarity search | [`algorithm/milvus/`](../../algorithm/milvus/) |
| **SELDON** | Seldon Core ML platform | Kubernetes-native ML serving | [`algorithm/seldon/`](../../algorithm/seldon/) |
| **TFSERVING** | TensorFlow Serving | TensorFlow model deployment | [`algorithm/tfserving/`](../../algorithm/tfserving/) |

### Adding New Types

To add a new algorithm type:

1. **Implement IAlgorithm interface**
2. **Add type to factory switch statement**
3. **Define configuration structure**
4. **Implement response interface**

Example:
```go
// 1. Implement interface
type MyCustomAlgorithm struct {
    config *MyConfig
}
func (a *MyCustomAlgorithm) Init(conf *recconf.AlgoConfig) error { /* ... */ }
func (a *MyCustomAlgorithm) Run(data interface{}) (interface{}, error) { /* ... */ }

// 2. Add to factory (modify algorithm.go)
case "MYCUSTOM":
    return NewMyCustomAlgorithm(), nil
```

## Key Design Principles

### 1. **Interface Segregation**
Small, focused interfaces make algorithms easy to implement:
```go
// ✅ Simple, focused interface
type IAlgorithm interface {
    Init(conf *recconf.AlgoConfig) error
    Run(algoData interface{}) (interface{}, error)
}

// ❌ Would be harder to implement
type IBigAlgorithm interface {
    Init() error
    Configure() error  
    Validate() error
    Run() error
    Cleanup() error
    GetMetrics() map[string]float64
    // ... 10+ more methods
}
```

### 2. **Dependency Injection via Configuration**
Algorithms receive everything they need through configuration:
```go
// Algorithm doesn't know about databases, just gets what it needs
type EasConfig struct {
    Url       string            `json:"url"`        // Where to call
    Auth      map[string]string `json:"auth"`       // How to authenticate  
    Timeout   int              `json:"timeout"`    // When to timeout
    Processor string           `json:"processor"`  // What type of processing
}
```

### 3. **Fail-Fast Initialization**
Problems are caught early during `Init()`, not during request handling:
```go
func (m *EasModel) Init(conf *recconf.AlgoConfig) error {
    // Validate configuration immediately
    if conf.EasConf.Url == "" {
        return fmt.Errorf("EAS URL cannot be empty")
    }
    
    // Test connectivity during initialization
    if err := m.testConnection(); err != nil {
        return fmt.Errorf("failed to connect to EAS: %v", err)
    }
    
    return nil
}
```

### 4. **Type Safety with Runtime Flexibility**
Strong typing where possible, flexibility where needed:
```go
// Typed configuration structures
type VectorConfig struct {
    ServerAddress string `json:"server_address"`
    Timeout       int    `json:"timeout"`
}

// Flexible input/output for different data types
func (m *FaissModel) Run(algoData interface{}) (interface{}, error) {
    // Handle different input types as needed
    switch data := algoData.(type) {
    case []float64:
        return m.searchVector(data)
    case map[string]interface{}:
        return m.searchFeatures(data)
    }
}
```

---

## Next Steps

Now that you understand the core concepts, you're ready to:

1. **[Get Started](02-getting-started.md)** - Set up your first algorithm
2. **[Explore Simple Algorithms](03-simple-algorithms.md)** - Learn with LOOKUP
3. **[Dive into Vector Search](04-vector-search.md)** - Advanced similarity search
4. **[Master ML Serving](05-ml-serving.md)** - Production ML integration

**Questions?** The [API Reference](10-api-reference.md) has complete technical details for every interface and method.