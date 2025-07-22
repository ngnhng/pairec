# API Reference

Complete technical reference for PaiRec's algorithm framework interfaces, types, and methods. This document serves as the definitive guide for developers working with PaiRec algorithms.

## Table of Contents
- [Core Interfaces](#core-interfaces)
- [Configuration Types](#configuration-types)
- [Response Types](#response-types)
- [Algorithm Factory API](#algorithm-factory-api)
- [Function Reference](#function-reference)
- [Error Types](#error-types)
- [Utility Functions](#utility-functions)
- [Examples](#examples)

## Core Interfaces

### IAlgorithm

The fundamental interface that all algorithms must implement.

```go
type IAlgorithm interface {
    Init(conf *recconf.AlgoConfig) error
    Run(algoData interface{}) (interface{}, error)
}
```

**📍 File Reference**: [`algorithm/algorithm.go:28-31`](../../algorithm/algorithm.go#L28-L31)

#### Init Method

Initializes the algorithm with configuration.

**Signature:**
```go
Init(conf *recconf.AlgoConfig) error
```

**Parameters:**
- `conf` - Algorithm configuration containing type-specific settings

**Returns:**
- `error` - Error if initialization fails, nil if successful

**Called:**
- Once during system startup
- When configuration is reloaded
- Before any Run() calls

**Example:**
```go
func (m *MyAlgorithm) Init(conf *recconf.AlgoConfig) error {
    if conf.MyConf.URL == "" {
        return fmt.Errorf("URL is required")
    }
    
    m.config = &conf.MyConf
    return nil
}
```

#### Run Method

Executes the algorithm on input data.

**Signature:**
```go
Run(algoData interface{}) (interface{}, error)
```

**Parameters:**
- `algoData` - Input data (format varies by algorithm type)

**Returns:**
- `interface{}` - Algorithm results (typically `[]AlgoResponse`)
- `error` - Error if execution fails

**Called:**
- For each recommendation request
- Multiple times concurrently

**Example:**
```go
func (m *MyAlgorithm) Run(algoData interface{}) (interface{}, error) {
    features := algoData.([]map[string]interface{})
    results := make([]response.AlgoResponse, len(features))
    
    for i, feature := range features {
        score := m.computeScore(feature)
        results[i] = &MyResponse{score: score}
    }
    
    return results, nil
}
```

### AlgoResponse

Interface for algorithm output responses.

```go
type AlgoResponse interface {
    GetScore() float64
    GetScoreMap() map[string]float64
    GetModuleType() bool
}
```

**📍 File Reference**: [`algorithm/response/response.go:3-7`](../../algorithm/response/response.go#L3-L7)

#### GetScore Method

Returns the primary relevance score.

**Signature:**
```go
GetScore() float64
```

**Returns:**
- `float64` - Primary score (typically 0.0 to 1.0)

**Usage:**
- Main score for ranking and sorting
- Should be normalized to comparable range

#### GetScoreMap Method

Returns multiple named scores.

**Signature:**
```go
GetScoreMap() map[string]float64
```

**Returns:**
- `map[string]float64` - Named scores (may be nil)

**Usage:**
- Multi-criteria scoring
- Feature-specific scores
- Debugging and analysis

#### GetModuleType Method

Returns algorithm type metadata.

**Signature:**
```go
GetModuleType() bool
```

**Returns:**
- `bool` - Algorithm complexity indicator

**Usage:**
- Differentiate simple vs complex algorithms
- Monitoring and metrics categorization

### AlgoMultiClassifyResponse

Extended interface for classification responses.

```go
type AlgoMultiClassifyResponse interface {
    GetClassifyMap() map[string][]float64
}
```

#### GetClassifyMap Method

Returns classification probabilities.

**Signature:**
```go
GetClassifyMap() map[string][]float64
```

**Returns:**
- `map[string][]float64` - Class name to probability array

**Usage:**
- Multi-class classification results
- Category predictions
- Sentiment analysis

**Example:**
```go
classifyMap := response.GetClassifyMap()
categories := classifyMap["product_category"]  // [0.6, 0.3, 0.1] for 3 categories
sentiments := classifyMap["sentiment"]         // [0.1, 0.2, 0.7] for neg/neu/pos
```

## Configuration Types

### AlgoConfig

Base configuration structure for all algorithms.

```go
type AlgoConfig struct {
    Name          string            `json:"name"`
    Type          string            `json:"type"`
    EasConf       EasConfig         `json:"eas_conf"`
    VectorConf    VectorConfig      `json:"vector_conf"`
    MilvusConf    MilvusConfig      `json:"milvus_conf"`
    LookupConf    LookupConfig      `json:"lookup_conf"`
    SeldonConf    SeldonConfig      `json:"seldon_conf"`
    TFservingConf TFservingConfig   `json:"tfserving_conf"`
}
```

**📍 File Reference**: [`recconf/recconf.go:249-258`](../../recconf/recconf.go#L249-L258)

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Name` | `string` | ✅ | Unique algorithm identifier |
| `Type` | `string` | ✅ | Algorithm type (EAS, FAISS, etc.) |
| `EasConf` | `EasConfig` | ❌ | EAS-specific configuration |
| `VectorConf` | `VectorConfig` | ❌ | FAISS configuration |
| `MilvusConf` | `MilvusConfig` | ❌ | Milvus configuration |
| `LookupConf` | `LookupConfig` | ❌ | LOOKUP configuration |
| `SeldonConf` | `SeldonConfig` | ❌ | Seldon configuration |
| `TFservingConf` | `TFservingConfig` | ❌ | TensorFlow Serving configuration |

### EasConfig

Configuration for Alibaba Cloud EAS algorithms.

```go
type EasConfig struct {
    Processor        string            `json:"processor"`
    Url              string            `json:"url"`
    Auth             map[string]string `json:"auth"`
    EndpointType     string            `json:"endpoint_type"`
    SignatureName    string            `json:"signature_name"`
    Timeout          int               `json:"timeout"`
    RetryTimes       int               `json:"retry_times"`
    ResponseFuncName string            `json:"response_func_name"`
    Outputs          []string          `json:"outputs"`
    ModelName        string            `json:"model_name"`
}
```

**📍 File Reference**: [`recconf/recconf.go:279-290`](../../recconf/recconf.go#L279-L290)

#### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `Processor` | `string` | ✅ | - | Model processor type |
| `Url` | `string` | ✅ | - | EAS endpoint URL |
| `Auth` | `map[string]string` | ❌ | `{}` | Authentication headers |
| `EndpointType` | `string` | ❌ | `""` | Endpoint type (direct, docker) |
| `SignatureName` | `string` | ❌ | `""` | TensorFlow signature name |
| `Timeout` | `int` | ✅ | - | Request timeout in milliseconds |
| `RetryTimes` | `int` | ❌ | `2` | Number of retry attempts |
| `ResponseFuncName` | `string` | ❌ | `""` | Custom response parser function |
| `Outputs` | `[]string` | ❌ | `[]` | Specific model outputs to return |
| `ModelName` | `string` | ❌ | `""` | Model identifier |

#### Processor Types

| Processor | Description | Use Case |
|-----------|-------------|----------|
| `ALINK_FM` | Factorization Machine | CTR prediction |
| `PMML` | PMML models | Traditional ML |
| `TensorFlow` | TensorFlow models | Deep learning |
| `TFServing` | TensorFlow Serving | Production TF models |
| `EasyRec` | Alibaba EasyRec | Large-scale recommendations |
| `Linucb` | Linear contextual bandits | Multi-armed bandits |

### VectorConfig

Configuration for FAISS vector search.

```go
type VectorConfig struct {
    ServerAddress string `json:"server_address"`
    Timeout       int64  `json:"timeout"`
}
```

**📍 File Reference**: [`recconf/recconf.go:303-306`](../../recconf/recconf.go#L303-L306)

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ServerAddress` | `string` | ✅ | FAISS gRPC server address |
| `Timeout` | `int64` | ✅ | Request timeout in milliseconds |

### MilvusConfig

Configuration for Milvus vector database.

```go
type MilvusConfig struct {
    ServerAddress string `json:"server_address"`
    Timeout       int64  `json:"timeout"`
}
```

**📍 File Reference**: [`recconf/recconf.go:307-310`](../../recconf/recconf.go#L307-L310)

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ServerAddress` | `string` | ✅ | Milvus server address |
| `Timeout` | `int64` | ✅ | Connection timeout in milliseconds |

### LookupConfig

Configuration for LOOKUP algorithm.

```go
type LookupConfig struct {
    FieldName string `json:"field_name"`
}
```

**📍 File Reference**: [`recconf/recconf.go:275-277`](../../recconf/recconf.go#L275-L277)

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `FieldName` | `string` | ✅ | Field name to extract score from |

### TFservingConfig

Configuration for TensorFlow Serving.

```go
type TFservingConfig struct {
    Url              string   `json:"url"`
    SignatureName    string   `json:"signature_name"`
    Timeout          int      `json:"timeout"`
    RetryTimes       int      `json:"retry_times"`
    ResponseFuncName string   `json:"response_func_name"`
    Outputs          []string `json:"outputs"`
}
```

**📍 File Reference**: [`recconf/recconf.go:291-298`](../../recconf/recconf.go#L291-L298)

#### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `Url` | `string` | ✅ | - | TF Serving REST endpoint |
| `SignatureName` | `string` | ❌ | `""` | Model signature name |
| `Timeout` | `int` | ✅ | - | Request timeout in milliseconds |
| `RetryTimes` | `int` | ❌ | `0` | Number of retry attempts |
| `ResponseFuncName` | `string` | ❌ | `""` | Custom response parser |
| `Outputs` | `[]string` | ❌ | `[]` | Specific outputs to return |

### SeldonConfig

Configuration for Seldon Core.

```go
type SeldonConfig struct {
    Url              string `json:"url"`
    ResponseFuncName string `json:"response_func_name"`
}
```

**📍 File Reference**: [`recconf/recconf.go:299-302`](../../recconf/recconf.go#L299-L302)

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Url` | `string` | ✅ | Seldon prediction endpoint |
| `ResponseFuncName` | `string` | ❌ | Custom response parser function |

## Response Types

### Standard Response Implementation

Example response implementation for reference:

```go
type StandardResponse struct {
    score       float64
    scoreMap    map[string]float64
    moduleType  bool
}

func (r *StandardResponse) GetScore() float64 {
    return r.score
}

func (r *StandardResponse) GetScoreMap() map[string]float64 {
    return r.scoreMap
}

func (r *StandardResponse) GetModuleType() bool {
    return r.moduleType
}
```

### Classification Response Implementation

```go
type ClassificationResponse struct {
    score       float64
    scoreMap    map[string]float64
    classifyMap map[string][]float64
}

func (r *ClassificationResponse) GetScore() float64 {
    return r.score
}

func (r *ClassificationResponse) GetScoreMap() map[string]float64 {
    return r.scoreMap
}

func (r *ClassificationResponse) GetModuleType() bool {
    return true
}

func (r *ClassificationResponse) GetClassifyMap() map[string][]float64 {
    return r.classifyMap
}
```

## Algorithm Factory API

### AlgorithmFactory

Central factory for managing algorithm instances.

```go
type AlgorithmFactory struct {
    algorithms       map[string]IAlgorithm
    requestDataFuncs map[string]RequestDataFunc
    mutex            sync.RWMutex
    algorithmSigns   map[string]string
}
```

**📍 File Reference**: [`algorithm/algorithm.go:33-38`](../../algorithm/algorithm.go#L33-L38)

### Public Functions

#### Load

Initializes algorithms from configuration.

**Signature:**
```go
func Load(config *recconf.RecommendConfig)
```

**Parameters:**
- `config` - Complete recommendation configuration

**Usage:**
```go
config := &recconf.RecommendConfig{
    AlgoConfs: []recconf.AlgoConfig{
        {Name: "test-algo", Type: "LOOKUP", LookupConf: recconf.LookupConfig{FieldName: "score"}},
    },
}
algorithm.Load(config)
```

**📍 File Reference**: [`algorithm/algorithm.go:123-125`](../../algorithm/algorithm.go#L123-L125)

#### Run

Executes an algorithm by name.

**Signature:**
```go
func Run(name string, algoData interface{}) (interface{}, error)
```

**Parameters:**
- `name` - Algorithm name from configuration
- `algoData` - Input data for algorithm

**Returns:**
- `interface{}` - Algorithm results
- `error` - Error if execution fails

**Usage:**
```go
result, err := algorithm.Run("my-algorithm", inputData)
if err != nil {
    log.Printf("Algorithm failed: %v", err)
    return
}

responses, ok := result.([]response.AlgoResponse)
if !ok {
    log.Printf("Unexpected response type: %T", result)
    return
}

for i, resp := range responses {
    fmt.Printf("Item %d: score=%.3f\n", i, resp.GetScore())
}
```

**📍 File Reference**: [`algorithm/algorithm.go:126-128`](../../algorithm/algorithm.go#L126-L128)

#### AddAlgo

Adds a single algorithm without signature checking.

**Signature:**
```go
func AddAlgo(conf recconf.AlgoConfig)
```

**Parameters:**
- `conf` - Algorithm configuration

**Usage:**
```go
config := recconf.AlgoConfig{
    Name: "new-algorithm",
    Type: "LOOKUP",
    LookupConf: recconf.LookupConfig{FieldName: "new_score"},
}
algorithm.AddAlgo(config)
```

**📍 File Reference**: [`algorithm/algorithm.go:129-142`](../../algorithm/algorithm.go#L129-L142)

#### AddAlgoWithSign

Adds algorithm with configuration signature checking.

**Signature:**
```go
func AddAlgoWithSign(conf recconf.AlgoConfig)
```

**Parameters:**
- `conf` - Algorithm configuration

**Behavior:**
- Only updates if configuration signature has changed
- Prevents unnecessary reinitialization

**Usage:**
```go
// Safe to call repeatedly - only updates if config changed
algorithm.AddAlgoWithSign(config)
```

**📍 File Reference**: [`algorithm/algorithm.go:143-162`](../../algorithm/algorithm.go#L143-L162)

#### RegisterAlgorithm

Registers a pre-instantiated algorithm.

**Signature:**
```go
func RegisterAlgorithm(name string, algo IAlgorithm)
```

**Parameters:**
- `name` - Algorithm name
- `algo` - Algorithm instance

**Usage:**
```go
myAlgo := &MyCustomAlgorithm{}
algorithm.RegisterAlgorithm("custom-algo", myAlgo)
```

**📍 File Reference**: [`algorithm/algorithm.go:164-168`](../../algorithm/algorithm.go#L164-L168)

#### RegistRequestDataFunc

Registers custom request data transformation function.

**Signature:**
```go
func RegistRequestDataFunc(name string, f RequestDataFunc)
```

**Type Definition:**
```go
type RequestDataFunc func(string, interface{}) interface{}
```

**Parameters:**
- `name` - Algorithm name
- `f` - Transformation function

**Usage:**
```go
algorithm.RegistRequestDataFunc("my-algo", func(name string, data interface{}) interface{} {
    // Transform data before algorithm processing
    return transformedData
})
```

**📍 File Reference**: [`algorithm/algorithm.go:172-174`](../../algorithm/algorithm.go#L172-L174)

## Function Reference

### Response Processing Functions

#### ResponseFunc Type

Function type for custom response processing.

**Type Definition:**
```go
type ResponseFunc func(interface{}) ([]AlgoResponse, error)
```

**Parameters:**
- `interface{}` - Raw algorithm output

**Returns:**
- `[]AlgoResponse` - Processed responses
- `error` - Processing error

**Usage:**
```go
func customResponseParser(rawResponse interface{}) ([]response.AlgoResponse, error) {
    // Parse raw response into structured AlgoResponse objects
    data := rawResponse.(map[string]interface{})
    predictions := data["predictions"].([]interface{})
    
    responses := make([]response.AlgoResponse, len(predictions))
    for i, pred := range predictions {
        score := pred.(float64)
        responses[i] = &StandardResponse{score: score}
    }
    
    return responses, nil
}
```

### Utility Functions

#### Algorithm Type Validation

```go
func IsValidAlgorithmType(algorithmType string) bool {
    validTypes := []string{"EAS", "FAISS", "LOOKUP", "MILVUS", "SELDON", "TFSERVING"}
    for _, valid := range validTypes {
        if algorithmType == valid {
            return true
        }
    }
    return false
}
```

#### Input Size Detection

```go
func GetInputSize(data interface{}) int {
    switch v := data.(type) {
    case []map[string]interface{}:
        return len(v)
    case []interface{}:
        return len(v)
    case map[string]interface{}:
        return 1
    default:
        return 0
    }
}
```

#### Score Validation

```go
func ValidateScore(score float64) bool {
    return !math.IsNaN(score) && !math.IsInf(score, 0)
}

func NormalizeScore(score float64, min, max float64) float64 {
    if max == min {
        return 0.5
    }
    return (score - min) / (max - min)
}
```

## Error Types

### Common Error Patterns

#### Algorithm Not Found

```go
// Error: "not found algorithm, name:algorithm-name"
// Cause: Algorithm not initialized or wrong name
// Solution: Check algorithm name in configuration and ensure Load() was called

result, err := algorithm.Run("nonexistent-algo", data)
if err != nil && strings.Contains(err.Error(), "not found algorithm") {
    // Handle missing algorithm
}
```

#### Unsupported Algorithm Type

```go
// Error: "algorithm type not support, type:INVALID_TYPE"
// Cause: Invalid algorithm type in configuration
// Solution: Use valid type: EAS, FAISS, LOOKUP, MILVUS, SELDON, TFSERVING

if err != nil && strings.Contains(err.Error(), "algorithm type not support") {
    // Handle invalid algorithm type
}
```

#### Initialization Error

```go
// Error: "init algorithm error, name:algo-name, err:specific-error"
// Cause: Algorithm-specific initialization failure
// Solution: Check algorithm-specific configuration

if err != nil && strings.Contains(err.Error(), "init algorithm error") {
    // Handle initialization failure
}
```

### Error Handling Best Practices

```go
func safeRunAlgorithm(name string, data interface{}) ([]response.AlgoResponse, error) {
    result, err := algorithm.Run(name, data)
    if err != nil {
        return nil, fmt.Errorf("algorithm %s failed: %w", name, err)
    }
    
    responses, ok := result.([]response.AlgoResponse)
    if !ok {
        return nil, fmt.Errorf("algorithm %s returned unexpected type: %T", name, result)
    }
    
    // Validate responses
    for i, resp := range responses {
        if resp == nil {
            return nil, fmt.Errorf("algorithm %s returned nil response at index %d", name, i)
        }
        
        score := resp.GetScore()
        if !ValidateScore(score) {
            return nil, fmt.Errorf("algorithm %s returned invalid score %f at index %d", name, score, i)
        }
    }
    
    return responses, nil
}
```

## Examples

### Complete Algorithm Implementation

```go
package custom

import (
    "fmt"
    "math"
    
    "github.com/alibaba/pairec/v2/algorithm/response"
    "github.com/alibaba/pairec/v2/recconf"
)

// Custom algorithm that computes weighted averages
type WeightedAverageAlgorithm struct {
    name    string
    weights map[string]float64
    defaultScore float64
}

type WeightedAverageResponse struct {
    score    float64
    weights  map[string]float64
    features map[string]float64
}

func (r *WeightedAverageResponse) GetScore() float64 {
    return r.score
}

func (r *WeightedAverageResponse) GetScoreMap() map[string]float64 {
    scoreMap := make(map[string]float64)
    for feature, score := range r.features {
        scoreMap[feature] = score
    }
    scoreMap["weighted_average"] = r.score
    return scoreMap
}

func (r *WeightedAverageResponse) GetModuleType() bool {
    return true
}

func NewWeightedAverageAlgorithm(name string) *WeightedAverageAlgorithm {
    return &WeightedAverageAlgorithm{
        name: name,
    }
}

func (w *WeightedAverageAlgorithm) Init(conf *recconf.AlgoConfig) error {
    // Extract configuration from LookupConf or custom field
    w.weights = map[string]float64{
        "relevance": 0.4,
        "popularity": 0.3,
        "quality": 0.2,
        "freshness": 0.1,
    }
    w.defaultScore = 0.5
    
    return nil
}

func (w *WeightedAverageAlgorithm) Run(algoData interface{}) (interface{}, error) {
    featureList, ok := algoData.([]map[string]interface{})
    if !ok {
        return nil, fmt.Errorf("expected []map[string]interface{}, got %T", algoData)
    }
    
    results := make([]response.AlgoResponse, len(featureList))
    
    for i, features := range featureList {
        weightedSum := 0.0
        totalWeight := 0.0
        featureScores := make(map[string]float64)
        
        for feature, weight := range w.weights {
            if value, exists := features[feature]; exists {
                if score, ok := value.(float64); ok {
                    weightedSum += score * weight
                    totalWeight += weight
                    featureScores[feature] = score
                }
            }
        }
        
        finalScore := w.defaultScore
        if totalWeight > 0 {
            finalScore = weightedSum / totalWeight
        }
        
        results[i] = &WeightedAverageResponse{
            score:    finalScore,
            weights:  w.weights,
            features: featureScores,
        }
    }
    
    return results, nil
}
```

### Configuration Example

```go
package main

import (
    "encoding/json"
    "fmt"
    "log"
    
    "github.com/alibaba/pairec/v2/algorithm"
    "github.com/alibaba/pairec/v2/recconf"
)

func main() {
    // Create configuration
    config := &recconf.RecommendConfig{
        AlgoConfs: []recconf.AlgoConfig{
            {
                Name: "simple-lookup",
                Type: "LOOKUP",
                LookupConf: recconf.LookupConfig{
                    FieldName: "score",
                },
            },
            {
                Name: "vector-similarity",
                Type: "FAISS",
                VectorConf: recconf.VectorConfig{
                    ServerAddress: "localhost:8080",
                    Timeout:       1000,
                },
            },
            {
                Name: "ml-ranker",
                Type: "EAS",
                EasConf: recconf.EasConfig{
                    Processor: "TensorFlow",
                    Url:       "https://ml-model.eas.com/predict",
                    Timeout:   800,
                    Auth: map[string]string{
                        "Authorization": "Bearer token",
                    },
                },
            },
        },
    }
    
    // Initialize algorithms
    algorithm.Load(config)
    
    // Test LOOKUP algorithm
    lookupData := []map[string]interface{}{
        {"item_id": "item1", "score": 0.85},
        {"item_id": "item2", "score": 0.72},
    }
    
    result, err := algorithm.Run("simple-lookup", lookupData)
    if err != nil {
        log.Fatalf("LOOKUP failed: %v", err)
    }
    
    responses := result.([]response.AlgoResponse)
    for i, resp := range responses {
        fmt.Printf("LOOKUP result %d: %.3f\n", i, resp.GetScore())
    }
    
    // Test other algorithms...
}
```

### Testing Example

```go
package algorithm_test

import (
    "testing"
    
    "github.com/alibaba/pairec/v2/algorithm"
    "github.com/alibaba/pairec/v2/algorithm/response"
    "github.com/alibaba/pairec/v2/recconf"
    "github.com/stretchr/testify/assert"
)

func TestAlgorithmIntegration(t *testing.T) {
    // Setup
    config := &recconf.RecommendConfig{
        AlgoConfs: []recconf.AlgoConfig{
            {
                Name: "test-lookup",
                Type: "LOOKUP",
                LookupConf: recconf.LookupConfig{
                    FieldName: "test_score",
                },
            },
        },
    }
    
    algorithm.Load(config)
    
    // Test data
    testData := []map[string]interface{}{
        {"item_id": "test1", "test_score": 0.9},
        {"item_id": "test2", "test_score": 0.7},
        {"item_id": "test3"}, // Missing score
    }
    
    // Execute
    result, err := algorithm.Run("test-lookup", testData)
    assert.NoError(t, err)
    
    // Validate
    responses, ok := result.([]response.AlgoResponse)
    assert.True(t, ok)
    assert.Len(t, responses, 3)
    
    assert.Equal(t, 0.9, responses[0].GetScore())
    assert.Equal(t, 0.7, responses[1].GetScore())
    assert.Equal(t, 0.5, responses[2].GetScore()) // Default fallback
}

func BenchmarkAlgorithmExecution(b *testing.B) {
    // Setup
    config := &recconf.RecommendConfig{
        AlgoConfs: []recconf.AlgoConfig{
            {
                Name: "bench-lookup",
                Type: "LOOKUP",
                LookupConf: recconf.LookupConfig{FieldName: "score"},
            },
        },
    }
    
    algorithm.Load(config)
    
    // Benchmark data
    data := make([]map[string]interface{}, 1000)
    for i := range data {
        data[i] = map[string]interface{}{
            "item_id": fmt.Sprintf("item_%d", i),
            "score":   rand.Float64(),
        }
    }
    
    // Benchmark
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, err := algorithm.Run("bench-lookup", data)
        if err != nil {
            b.Fatal(err)
        }
    }
}
```

---

## Summary

This API reference provides complete technical documentation for:

- **Core interfaces** that define algorithm contracts
- **Configuration types** for all supported algorithm types
- **Response interfaces** for handling algorithm outputs
- **Factory methods** for algorithm management
- **Error patterns** and handling strategies
- **Complete examples** for implementation and testing

### Quick Reference

| Operation | Function | Description |
|-----------|----------|-------------|
| **Initialize** | `algorithm.Load(config)` | Load algorithms from configuration |
| **Execute** | `algorithm.Run(name, data)` | Execute algorithm by name |
| **Add** | `algorithm.AddAlgo(config)` | Add single algorithm |
| **Register** | `algorithm.RegisterAlgorithm(name, algo)` | Register custom algorithm |
| **Transform** | `algorithm.RegistRequestDataFunc(name, func)` | Register data transformation |

### Algorithm Types

| Type | Config Field | Purpose |
|------|-------------|---------|
| `EAS` | `eas_conf` | Alibaba Cloud ML serving |
| `FAISS` | `vector_conf` | Vector similarity search |
| `LOOKUP` | `lookup_conf` | Simple score extraction |
| `MILVUS` | `milvus_conf` | Vector database |
| `SELDON` | `seldon_conf` | Seldon Core ML platform |
| `TFSERVING` | `tfserving_conf` | TensorFlow Serving |

This completes the comprehensive algorithm documentation for PaiRec. Use this reference for implementing, configuring, and integrating algorithms in your recommendation systems.