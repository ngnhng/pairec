# Configuration Guide

This comprehensive guide covers all aspects of configuring PaiRec algorithms, from basic setup to advanced production patterns. Learn how to configure, validate, and manage algorithm configurations effectively.

## Table of Contents
- [Configuration Overview](#configuration-overview)
- [Algorithm Configuration Structure](#algorithm-configuration-structure)
- [Algorithm-Specific Configurations](#algorithm-specific-configurations)
- [Advanced Configuration Patterns](#advanced-configuration-patterns)
- [Environment Management](#environment-management)
- [Configuration Validation](#configuration-validation)
- [Dynamic Configuration Updates](#dynamic-configuration-updates)
- [Production Best Practices](#production-best-practices)

## Configuration Overview

### Configuration-Driven Architecture

PaiRec follows a **configuration-driven** approach where algorithms, data sources, and processing pipelines are defined through JSON configuration files rather than code changes.

**Benefits:**
- **Zero Downtime Updates**: Change algorithms without recompilation
- **Environment Separation**: Different configs for dev/staging/prod
- **A/B Testing**: Easy model variant testing
- **Non-Technical Configuration**: Product teams can modify algorithms
- **Consistent Deployment**: Same code, different configs

### Configuration Hierarchy

```
RecommendConfig (Root)
├── AlgoConfs []          # Algorithm configurations
├── RecallConfs []        # Recall algorithm configs
├── FilterConfs []        # Filter configurations
├── SortConfs []          # Sorting configurations
├── SceneConfs {}         # Scene-specific settings
├── DataSource Configs {} # Database connections
└── Runtime Settings      # Logging, monitoring, etc.
```

### Core Configuration File Structure

```json
{
  "listen_conf": {
    "http_addr": "0.0.0.0",
    "http_port": 8000
  },
  "algo_confs": [
    {
      "name": "algorithm-name",
      "type": "ALGORITHM_TYPE",
      "specific_conf": {
        // Algorithm-specific configuration
      }
    }
  ],
  "scene_confs": {
    "scene_id": {
      "category": {
        "algo_names": ["algorithm-name"],
        "recall_names": ["recall-name"],
        "filter_names": ["filter-name"],
        "sort_names": ["sort-name"]
      }
    }
  }
}
```

## Algorithm Configuration Structure

### Base Algorithm Configuration

Every algorithm configuration includes these common fields:

```go
type AlgoConfig struct {
    Name          string            `json:"name"`           // Unique algorithm identifier
    Type          string            `json:"type"`           // Algorithm type (EAS, FAISS, etc.)
    
    // Algorithm-specific configurations
    EasConf       EasConfig         `json:"eas_conf"`
    VectorConf    VectorConfig      `json:"vector_conf"`
    MilvusConf    MilvusConfig      `json:"milvus_conf"`
    LookupConf    LookupConfig      `json:"lookup_conf"`
    SeldonConf    SeldonConfig      `json:"seldon_conf"`
    TFservingConf TFservingConfig   `json:"tfserving_conf"`
}
```

**📍 File Reference**: [`recconf/recconf.go:249-258`](../../recconf/recconf.go#L249-L258)

### Algorithm Type Mapping

| Type String | Configuration Field | Purpose |
|-------------|---------------------|---------|
| `"EAS"` | `eas_conf` | Alibaba Cloud ML serving |
| `"FAISS"` | `vector_conf` | Facebook AI Similarity Search |
| `"MILVUS"` | `milvus_conf` | Vector database |
| `"LOOKUP"` | `lookup_conf` | Simple score lookup |
| `"SELDON"` | `seldon_conf` | Seldon Core ML platform |
| `"TFSERVING"` | `tfserving_conf` | TensorFlow Serving |

### Configuration Example - Multi-Algorithm Setup

```json
{
  "algo_confs": [
    {
      "name": "content-similarity",
      "type": "FAISS",
      "vector_conf": {
        "server_address": "faiss-server:8080",
        "timeout": 500
      }
    },
    {
      "name": "neural-ranker",
      "type": "EAS", 
      "eas_conf": {
        "processor": "TensorFlow",
        "url": "https://eas-endpoint.com/api/predict/ranking",
        "timeout": 800,
        "retry_times": 3,
        "auth": {
          "Authorization": "Bearer ${EAS_TOKEN}"
        },
        "signature_name": "serving_default",
        "outputs": ["scores", "probabilities"]
      }
    },
    {
      "name": "popularity-baseline",
      "type": "LOOKUP",
      "lookup_conf": {
        "field_name": "popularity_score"
      }
    }
  ]
}
```

## Algorithm-Specific Configurations

### EAS Configuration

For Alibaba Cloud Elastic Algorithm Service:

```go
type EasConfig struct {
    Processor        string            `json:"processor"`         // Model processor type
    Url              string            `json:"url"`               // EAS endpoint URL
    Auth             map[string]string `json:"auth"`              // Authentication headers
    EndpointType     string            `json:"endpoint_type"`     // direct, docker
    SignatureName    string            `json:"signature_name"`    // TensorFlow signature
    Timeout          int               `json:"timeout"`           // Request timeout (ms)
    RetryTimes       int               `json:"retry_times"`       // Retry attempts
    ResponseFuncName string            `json:"response_func_name"` // Custom response parser
    Outputs          []string          `json:"outputs"`           // Specific model outputs
    ModelName        string            `json:"model_name"`        // Model identifier
}
```

**📍 File Reference**: [`recconf/recconf.go:279-290`](../../recconf/recconf.go#L279-L290)

#### EAS Configuration Examples

**Basic TensorFlow Model:**
```json
{
  "name": "tf-ranker",
  "type": "EAS",
  "eas_conf": {
    "processor": "TensorFlow",
    "url": "https://model.cn-beijing.pai-eas.aliyuncs.com/api/predict/ranking",
    "timeout": 1000,
    "retry_times": 2
  }
}
```

**Authenticated EAS with Custom Response:**
```json
{
  "name": "secure-model",
  "type": "EAS",
  "eas_conf": {
    "processor": "EasyRec",
    "url": "https://secured-model.eas.com/api/predict/recommender",
    "auth": {
      "Authorization": "Bearer your-token-here",
      "X-Custom-Header": "custom-value"
    },
    "timeout": 1500,
    "retry_times": 3,
    "response_func_name": "CustomEasyRecParser",
    "outputs": ["item_scores", "user_embeddings", "explanations"]
  }
}
```

**Docker Endpoint Configuration:**
```json
{
  "name": "docker-model",
  "type": "EAS",
  "eas_conf": {
    "processor": "EasyRec",
    "url": "http://easyrec-service:8080/predict",
    "endpoint_type": "docker",
    "timeout": 2000
  }
}
```

### Vector Search Configurations

#### FAISS Configuration

```go
type VectorConfig struct {
    ServerAddress string `json:"server_address"`  // gRPC server address
    Timeout       int64  `json:"timeout"`         // Timeout in milliseconds
}
```

```json
{
  "name": "item-similarity",
  "type": "FAISS",
  "vector_conf": {
    "server_address": "faiss-server:8080",
    "timeout": 300
  }
}
```

#### Milvus Configuration

```go
type MilvusConfig struct {
    ServerAddress string `json:"server_address"`  // Milvus server address
    Timeout       int64  `json:"timeout"`         // Connection timeout
}
```

```json
{
  "name": "semantic-search",
  "type": "MILVUS",
  "milvus_conf": {
    "server_address": "milvus-cluster:19530",
    "timeout": 2000
  }
}
```

### Simple Algorithm Configurations

#### LOOKUP Configuration

```go
type LookupConfig struct {
    FieldName string `json:"field_name"`  // Field to extract score from
}
```

```json
{
  "name": "precomputed-scores",
  "type": "LOOKUP",
  "lookup_conf": {
    "field_name": "ml_score"
  }
}
```

### ML Platform Configurations

#### TensorFlow Serving Configuration

```go
type TFservingConfig struct {
    Url              string   `json:"url"`                // TF Serving REST endpoint
    SignatureName    string   `json:"signature_name"`     // Model signature
    Timeout          int      `json:"timeout"`            // Request timeout
    RetryTimes       int      `json:"retry_times"`        // Retry attempts
    ResponseFuncName string   `json:"response_func_name"` // Custom parser
    Outputs          []string `json:"outputs"`            // Specific outputs
}
```

```json
{
  "name": "tf-classifier",
  "type": "TFSERVING",
  "tfserving_conf": {
    "url": "http://tf-serving:8501/v1/models/classifier:predict",
    "signature_name": "classification_signature",
    "timeout": 800,
    "retry_times": 2,
    "outputs": ["probabilities", "features"]
  }
}
```

#### Seldon Configuration

```go
type SeldonConfig struct {
    Url              string `json:"url"`                // Seldon prediction endpoint
    ResponseFuncName string `json:"response_func_name"` // Custom response parser
}
```

```json
{
  "name": "seldon-ensemble",
  "type": "SELDON",
  "seldon_conf": {
    "url": "http://seldon-model.seldon:8000/api/v1.0/predictions",
    "response_func_name": "SeldonEnsembleParser"
  }
}
```

## Advanced Configuration Patterns

### Environment-Based Configuration

#### Development Environment
```json
{
  "algo_confs": [
    {
      "name": "dev-ranker",
      "type": "LOOKUP",
      "lookup_conf": {
        "field_name": "random_score"
      }
    }
  ],
  "listen_conf": {
    "http_port": 8000,
    "http_addr": "localhost"
  }
}
```

#### Staging Environment
```json
{
  "algo_confs": [
    {
      "name": "staging-ranker",
      "type": "TFSERVING",
      "tfserving_conf": {
        "url": "http://staging-tf:8501/v1/models/ranker:predict",
        "timeout": 2000,
        "retry_times": 1
      }
    }
  ]
}
```

#### Production Environment
```json
{
  "algo_confs": [
    {
      "name": "prod-ranker",
      "type": "EAS",
      "eas_conf": {
        "processor": "TensorFlow",
        "url": "https://prod-model.cn-beijing.pai-eas.aliyuncs.com/api/predict/ranker",
        "timeout": 500,
        "retry_times": 3,
        "auth": {
          "Authorization": "Bearer ${PROD_EAS_TOKEN}"
        }
      }
    }
  ]
}
```

### Multi-Model Ensemble Configuration

```json
{
  "algo_confs": [
    {
      "name": "collaborative-filter",
      "type": "EAS",
      "eas_conf": {
        "processor": "ALINK_FM",
        "url": "https://cf-model.eas.com/predict",
        "timeout": 400
      }
    },
    {
      "name": "content-based",
      "type": "FAISS",
      "vector_conf": {
        "server_address": "content-faiss:8080",
        "timeout": 300
      }
    },
    {
      "name": "popularity-boost",
      "type": "LOOKUP",
      "lookup_conf": {
        "field_name": "popularity"
      }
    }
  ],
  "scene_confs": {
    "homepage": {
      "general": {
        "algo_names": ["collaborative-filter", "content-based", "popularity-boost"]
      }
    }
  }
}
```

### A/B Testing Configuration

```json
{
  "algo_confs": [
    {
      "name": "model-v1",
      "type": "EAS",
      "eas_conf": {
        "url": "https://model-v1.eas.com/predict",
        "processor": "TensorFlow"
      }
    },
    {
      "name": "model-v2",
      "type": "EAS", 
      "eas_conf": {
        "url": "https://model-v2.eas.com/predict",
        "processor": "TensorFlow"
      }
    }
  ],
  "abtest_conf": {
    "experiment_name": "ranking_model_test",
    "variants": {
      "control": {
        "traffic_percentage": 70,
        "algo_names": ["model-v1"]
      },
      "treatment": {
        "traffic_percentage": 30,
        "algo_names": ["model-v2"]
      }
    }
  }
}
```

### Load Balancing Configuration

```json
{
  "algo_confs": [
    {
      "name": "ranker-1",
      "type": "EAS",
      "eas_conf": {
        "url": "https://ranker-1.eas.com/predict",
        "timeout": 500
      }
    },
    {
      "name": "ranker-2", 
      "type": "EAS",
      "eas_conf": {
        "url": "https://ranker-2.eas.com/predict",
        "timeout": 500
      }
    },
    {
      "name": "ranker-lb",
      "type": "LOAD_BALANCER",
      "load_balancer_conf": {
        "strategy": "round_robin",
        "backends": ["ranker-1", "ranker-2"],
        "health_check": {
          "enabled": true,
          "interval": 30,
          "timeout": 5
        }
      }
    }
  ]
}
```

## Environment Management

### Environment Variables in Configuration

Use environment variables for sensitive or environment-specific values:

```json
{
  "algo_confs": [
    {
      "name": "secure-model",
      "type": "EAS",
      "eas_conf": {
        "url": "${EAS_ENDPOINT_URL}",
        "auth": {
          "Authorization": "Bearer ${EAS_ACCESS_TOKEN}"
        },
        "timeout": "${EAS_TIMEOUT:1000}"
      }
    }
  ],
  "mysql_confs": {
    "main": {
      "user": "${DB_USER}",
      "password": "${DB_PASSWORD}",
      "host": "${DB_HOST:localhost}",
      "port": "${DB_PORT:3306}"
    }
  }
}
```

### Configuration Templates

#### Base Template (`base.json`)
```json
{
  "listen_conf": {
    "http_addr": "0.0.0.0",
    "http_port": 8000
  },
  "log_conf": {
    "log_level": "info",
    "log_path": "/var/log/pairec"
  }
}
```

#### Environment Overlay (`prod.json`)
```json
{
  "algo_confs": [
    {
      "name": "prod-ranker",
      "type": "EAS",
      "eas_conf": {
        "url": "https://prod-endpoint.com",
        "timeout": 300,
        "retry_times": 3
      }
    }
  ],
  "log_conf": {
    "log_level": "warn"
  }
}
```

#### Merge Strategy
```bash
# Merge base config with environment-specific overrides
pairec -config base.json -config-overlay prod.json
```

### Kubernetes Configuration Management

#### ConfigMap for Base Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pairec-config
data:
  config.json: |
    {
      "algo_confs": [
        {
          "name": "k8s-ranker",
          "type": "TFSERVING",
          "tfserving_conf": {
            "url": "http://tf-serving.ml:8501/v1/models/ranker:predict",
            "timeout": 1000
          }
        }
      ]
    }
```

#### Secret for Sensitive Data
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: pairec-secrets
data:
  eas-token: <base64-encoded-token>
  db-password: <base64-encoded-password>
```

#### Deployment with Configuration
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pairec
spec:
  template:
    spec:
      containers:
      - name: pairec
        image: pairec:latest
        env:
        - name: EAS_ACCESS_TOKEN
          valueFrom:
            secretKeyRef:
              name: pairec-secrets
              key: eas-token
        volumeMounts:
        - name: config
          mountPath: /etc/pairec
      volumes:
      - name: config
        configMap:
          name: pairec-config
```

## Configuration Validation

### Built-in Validation

PaiRec includes configuration validation to catch errors early:

```go
func validateAlgoConfig(config AlgoConfig) error {
    if config.Name == "" {
        return errors.New("algorithm name cannot be empty")
    }
    
    switch config.Type {
    case "EAS":
        return validateEasConfig(config.EasConf)
    case "FAISS":
        return validateVectorConfig(config.VectorConf)
    case "LOOKUP":
        return validateLookupConfig(config.LookupConf)
    default:
        return fmt.Errorf("unsupported algorithm type: %s", config.Type)
    }
}

func validateEasConfig(config EasConfig) error {
    if config.Url == "" {
        return errors.New("EAS URL is required")
    }
    if config.Timeout <= 0 {
        return errors.New("EAS timeout must be positive")
    }
    return nil
}
```

### Custom Validation Rules

```go
type ValidationRule func(AlgoConfig) error

var customValidationRules = []ValidationRule{
    validateModelVersionCompatibility,
    validateResourceLimits,
    validateSecuritySettings,
}

func validateModelVersionCompatibility(config AlgoConfig) error {
    if config.Type == "EAS" && config.EasConf.Processor == "TensorFlow" {
        if config.EasConf.SignatureName == "" {
            return errors.New("TensorFlow models require signature_name")
        }
    }
    return nil
}

func validateResourceLimits(config AlgoConfig) error {
    maxTimeout := 10000 // 10 seconds
    
    switch config.Type {
    case "EAS":
        if config.EasConf.Timeout > maxTimeout {
            return fmt.Errorf("EAS timeout %d exceeds maximum %d", 
                config.EasConf.Timeout, maxTimeout)
        }
    case "TFSERVING":
        if config.TFservingConf.Timeout > maxTimeout {
            return fmt.Errorf("TF Serving timeout exceeds maximum")
        }
    }
    return nil
}
```

### Configuration Testing

```go
func TestAlgorithmConfiguration(t *testing.T) {
    config := AlgoConfig{
        Name: "test-model",
        Type: "EAS",
        EasConf: EasConfig{
            Url:       "https://test-endpoint.com",
            Processor: "TensorFlow",
            Timeout:   1000,
        },
    }
    
    // Test configuration validation
    err := validateAlgoConfig(config)
    assert.NoError(t, err)
    
    // Test algorithm initialization
    algo, err := initializeAlgorithm(config)
    assert.NoError(t, err)
    assert.NotNil(t, algo)
    
    // Test connectivity (if in integration test)
    if testing.Short() {
        t.Skip("Skipping connectivity test in short mode")
    }
    
    err = testAlgorithmConnectivity(algo)
    assert.NoError(t, err)
}
```

## Dynamic Configuration Updates

### Hot Reloading

PaiRec supports updating algorithm configurations without restart:

```go
// Watch for configuration file changes
func watchConfigFile(configPath string) {
    watcher, err := fsnotify.NewWatcher()
    if err != nil {
        log.Fatal(err)
    }
    defer watcher.Close()
    
    watcher.Add(configPath)
    
    for {
        select {
        case event := <-watcher.Events:
            if event.Op&fsnotify.Write == fsnotify.Write {
                log.Info("Config file modified: %s", event.Name)
                reloadConfiguration(configPath)
            }
        case err := <-watcher.Errors:
            log.Error("Config watch error: %v", err)
        }
    }
}

func reloadConfiguration(configPath string) {
    newConfig, err := loadConfigFromFile(configPath)
    if err != nil {
        log.Error("Failed to load new config: %v", err)
        return
    }
    
    // Validate before applying
    if err := validateConfiguration(newConfig); err != nil {
        log.Error("Invalid configuration: %v", err)
        return
    }
    
    // Apply new configuration
    algorithm.Load(newConfig)
    log.Info("Configuration reloaded successfully")
}
```

### Remote Configuration Management

```go
// Fetch configuration from remote source
func fetchRemoteConfig(configURL string) (*RecommendConfig, error) {
    resp, err := http.Get(configURL)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    var config RecommendConfig
    if err := json.NewDecoder(resp.Body).Decode(&config); err != nil {
        return nil, err
    }
    
    return &config, nil
}

// Poll for configuration updates
func pollConfigUpdates(configURL string, interval time.Duration) {
    ticker := time.NewTicker(interval)
    defer ticker.Stop()
    
    var lastConfigHash string
    
    for range ticker.C {
        config, err := fetchRemoteConfig(configURL)
        if err != nil {
            log.Error("Failed to fetch remote config: %v", err)
            continue
        }
        
        configHash := computeConfigHash(config)
        if configHash != lastConfigHash {
            log.Info("Remote configuration updated")
            algorithm.Load(config)
            lastConfigHash = configHash
        }
    }
}
```

### Configuration Versioning

```json
{
  "_meta": {
    "version": "1.2.3",
    "updated_at": "2024-01-15T10:30:00Z",
    "updated_by": "user@company.com",
    "change_description": "Updated ranking model to v2.1"
  },
  "algo_confs": [
    {
      "name": "ranker-v2",
      "type": "EAS",
      "eas_conf": {
        "url": "https://model-v2.1.eas.com/predict"
      }
    }
  ]
}
```

## Production Best Practices

### Security Best Practices

#### 1. **Secure Credential Management**
```json
{
  "algo_confs": [
    {
      "name": "secure-model",
      "type": "EAS",
      "eas_conf": {
        "url": "https://model.eas.com/predict",
        "auth": {
          "Authorization": "Bearer ${EAS_TOKEN}"  // Use env var, not hardcoded
        }
      }
    }
  ]
}
```

#### 2. **Network Security**
```json
{
  "algo_confs": [
    {
      "name": "internal-model",
      "type": "TFSERVING",
      "tfserving_conf": {
        "url": "https://internal-tf-serving.company.com:8501",  // HTTPS + internal domain
        "timeout": 1000
      }
    }
  ]
}
```

#### 3. **Input Validation**
```go
func validateAlgorithmInput(data interface{}) error {
    // Validate input size
    if reflect.ValueOf(data).Len() > maxInputSize {
        return errors.New("input size exceeds limit")
    }
    
    // Validate input format
    if !isValidInputFormat(data) {
        return errors.New("invalid input format")
    }
    
    return nil
}
```

### Performance Best Practices

#### 1. **Timeout Configuration**
```json
{
  "algo_confs": [
    {
      "name": "fast-model",
      "type": "EAS",
      "eas_conf": {
        "timeout": 200,      // Fast timeout for real-time serving
        "retry_times": 1     // Limited retries for latency
      }
    },
    {
      "name": "batch-model",
      "type": "MILVUS",
      "milvus_conf": {
        "timeout": 5000      // Longer timeout for batch processing
      }
    }
  ]
}
```

#### 2. **Connection Pooling**
```json
{
  "mysql_confs": {
    "main": {
      "max_open_conns": 20,
      "max_idle_conns": 10,
      "conn_max_lifetime": 3600
    }
  },
  "redis_confs": {
    "cache": {
      "pool_size": 50,
      "min_idle_conns": 10
    }
  }
}
```

#### 3. **Resource Limits**
```json
{
  "algo_confs": [
    {
      "name": "resource-limited-model",
      "type": "EAS",
      "eas_conf": {
        "timeout": 1000,
        "retry_times": 2,
        "max_concurrent_requests": 100
      }
    }
  ]
}
```

### Monitoring and Observability

#### 1. **Prometheus Metrics**
```json
{
  "prometheus_config": {
    "enable": true,
    "subsystem": "pairec",
    "push_gateway_url": "http://prometheus-pushgateway:9091",
    "push_interval_secs": 30,
    "job": "pairec-algorithms"
  }
}
```

#### 2. **Health Check Configuration**
```json
{
  "health_check": {
    "enable": true,
    "interval": 30,
    "timeout": 5,
    "algorithms": ["critical-ranker", "fallback-model"]
  }
}
```

#### 3. **Logging Configuration**
```json
{
  "log_conf": {
    "log_level": "info",
    "log_path": "/var/log/pairec/algorithms.log",
    "log_format": "json",
    "max_size": 100,
    "max_backups": 7,
    "max_age": 30
  }
}
```

### Error Handling Configuration

#### 1. **Fallback Strategies**
```json
{
  "algo_confs": [
    {
      "name": "primary-ranker",
      "type": "EAS",
      "eas_conf": {
        "url": "https://primary-model.eas.com",
        "timeout": 800,
        "fallback_algorithm": "backup-ranker"
      }
    },
    {
      "name": "backup-ranker",
      "type": "LOOKUP",
      "lookup_conf": {
        "field_name": "popularity_score"
      }
    }
  ]
}
```

#### 2. **Circuit Breaker Configuration**
```json
{
  "circuit_breaker": {
    "failure_threshold": 5,
    "timeout": 60,
    "max_requests": 3,
    "algorithms": ["external-model"]
  }
}
```

### Deployment Strategies

#### 1. **Blue-Green Deployment**
```json
{
  "algo_confs": [
    {
      "name": "blue-ranker",
      "type": "EAS",
      "eas_conf": {
        "url": "https://blue-env.eas.com/predict"
      }
    },
    {
      "name": "green-ranker", 
      "type": "EAS",
      "eas_conf": {
        "url": "https://green-env.eas.com/predict"
      }
    }
  ],
  "deployment": {
    "strategy": "blue_green",
    "active_environment": "blue",
    "traffic_split": {
      "blue": 100,
      "green": 0
    }
  }
}
```

#### 2. **Canary Deployment**
```json
{
  "deployment": {
    "strategy": "canary",
    "traffic_split": {
      "stable": 90,
      "canary": 10
    },
    "canary_config": {
      "name": "canary-ranker",
      "type": "EAS",
      "eas_conf": {
        "url": "https://canary-model.eas.com/predict"
      }
    }
  }
}
```

---

## Summary

Effective configuration management in PaiRec enables:

- **Flexible algorithm deployment** through configuration-driven architecture
- **Environment separation** with template-based configuration management
- **Security best practices** with proper credential management
- **Performance optimization** through appropriate timeout and resource settings
- **Operational excellence** with monitoring, health checks, and fallback strategies

### Key Takeaways

1. **Use environment variables** for sensitive and environment-specific values
2. **Implement configuration validation** to catch errors early
3. **Enable hot reloading** for zero-downtime updates
4. **Configure appropriate timeouts** based on algorithm characteristics
5. **Set up monitoring and alerting** for production visibility
6. **Plan fallback strategies** for error resilience

### Next Steps

- **[Custom Algorithms](08-custom-algorithms.md)** - Build algorithms with custom configuration options
- **[Performance Optimization](09-performance.md)** - Production tuning and scaling strategies
- **[API Reference](10-api-reference.md)** - Complete configuration structure reference