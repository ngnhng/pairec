# PaiRec Tutorial: Understanding the Key Abstractions

This tutorial provides a beginner-friendly guide to understanding PaiRec's core architecture and key abstractions. We'll cover the essential concepts that every developer needs to know to effectively work with PaiRec, presented in optimal teaching order from highest-level entry points to lower-level implementation details.

## Quick Reference

| Abstraction | Purpose | Key Files | Why Important |
|-------------|---------|-----------|---------------|
| [Request Flow](#1-the-complete-request-flow) | End-to-end recommendation journey | `/pairec.go`, `/web/recommend_controller.go` | Understanding the big picture |
| [Configuration](#2-configuration-system) | JSON-driven system customization | `/recconf/recconf.go`, `/examples/*.json` | Foundation for all customization |
| [Web Controllers](#3-web-controllers) | HTTP API entry points | `/web/recommend_controller.go` | User-facing interfaces |
| [Service Layer](#4-service-layer) | Business logic orchestration | `/service/recommend.go` | Core workflow management |
| [Processing Pipeline](#5-processing-pipeline) | Recall→Filter→Rank→Sort workflow | `/service/recall/`, `/filter/`, `/sort/` | Heart of recommendation logic |
| [Data Sources](#6-data-sources--persistence) | Unified data access | `/persist/`, `/module/*_dao.go` | How data flows into system |
| [Algorithm Integration](#7-algorithm-integration) | ML model serving | `/algorithm/`, `/algorithm/eas/` | AI/ML capabilities |
| [Context & A/B Testing](#8-context--ab-testing) | Request state & experiments | `/context/`, `/abtest/` | Production operation essentials |

## Table of Contents

1. [The Complete Request Flow](#1-the-complete-request-flow) - Understanding the user journey
2. [Configuration System](#2-configuration-system) - The foundation of customization
3. [Web Controllers](#3-web-controllers) - API entry points
4. [Service Layer](#4-service-layer) - Business logic orchestration
5. [Processing Pipeline](#5-processing-pipeline) - The recommendation workflow
6. [Data Sources & Persistence](#6-data-sources--persistence) - Data access patterns
7. [Algorithm Integration](#7-algorithm-integration) - ML model serving
8. [Context & A/B Testing](#8-context--ab-testing) - Request context and experiments

---

## 1. The Complete Request Flow

**What it is**: The end-to-end journey of a recommendation request from API call to response.

**Why it matters**: Understanding this flow gives you the big picture of how all components work together.

### The Flow in Detail

```
HTTP Request → Web Controller → Service Layer → Processing Pipeline → HTTP Response
     ↓              ↓               ↓                    ↓                ↓
1. Parse JSON   2. Load User     3. Execute      4. Recall → Filter   5. Format &
   Validate        Context         Business        → Rank → Sort        Return JSON
   Parameters      Setup           Logic           Pipeline             + Metrics
```

### Example: A Typical Recommendation Request

```bash
curl -X POST http://localhost:8000/api/recommend \
  -H "Content-Type: application/json" \
  -d '{
    "scene_id": "homepage",
    "uid": "user123", 
    "size": 10,
    "features": {
      "location": "san_francisco",
      "device": "mobile"
    }
  }'
```

**What happens internally**:

1. **Web Controller** (`/web/recommend_controller.go`) receives the request
2. **Request Context** is created with user ID, scene, and features
3. **Service Layer** orchestrates the recommendation pipeline
4. **Processing Pipeline** executes: Recall → Filter → Rank → Sort
5. **Response** is formatted and returned as JSON

### Key Files
- **Entry Point**: `/pairec.go` - Application initialization
- **Main Controller**: `/web/recommend_controller.go` - Request handling
- **Core Service**: `/service/recommend.go` - Business logic
- **Context**: `/context/recommend_context.go` - Request state management

---

## 2. Configuration System

**What it is**: A JSON-based configuration system that defines how PaiRec behaves for different scenarios.

**Why it matters**: PaiRec is configuration-driven - understanding configs is essential for customization.

### Configuration Structure

Every PaiRec deployment is controlled by a configuration file that defines:

```json
{
  "listen_conf": {
    "http_port": 8000,
    "http_addr": "0.0.0.0"
  },
  "scene_confs": [
    {
      "scene_id": "homepage",
      "recall_names": ["collaborative_filtering", "popular_items"],
      "filter_names": ["quality_filter", "diversity_filter"],
      "sort_names": ["ml_ranking"],
      "conf": {
        "recall_count": 1000,
        "final_count": 50
      }
    }
  ],
  "algo_confs": [...],
  "filter_confs": [...],
  "sort_confs": [...],
  "dao_conf": {...}
}
```

### Key Configuration Concepts

#### Scenes
**What**: Different use cases or contexts (homepage, product page, search results)
**How**: Each scene defines its own pipeline configuration

```json
{
  "scene_id": "product_detail",
  "recall_names": ["similar_products", "frequently_bought_together"],
  "filter_names": ["inventory_filter"],
  "sort_names": ["similarity_ranking"]
}
```

#### Pipeline Components
- **recall_names**: Which algorithms generate candidate items
- **filter_names**: Which business rules filter candidates  
- **sort_names**: Which algorithms rank/sort final results

### Configuration Loading

PaiRec supports two configuration modes:

1. **Local File**: `./pairec -config config.json`
2. **Remote Config**: Set `CONFIG_NAME` environment variable

```go
// From pairec.go
configName := os.Getenv("CONFIG_NAME")
if configName != "" {
    abtest.LoadFromEnvironment()
    ListenConfig(configName)
} else {
    err := recconf.LoadConfig(configFile)
    if err != nil {
        panic(err)
    }
}
```

### Key Files
- **Config Structure**: `/recconf/recconf.go` - Main configuration types
- **Loading Logic**: `/pairec.go` - Configuration initialization
- **Examples**: `/examples/basic-config.json`, `/examples/ecommerce-config.json`

---

## 3. Web Controllers

**What it is**: HTTP request handlers that provide different API endpoints.

**Why it matters**: Controllers are your entry points - they define what APIs PaiRec exposes.

### Available Controllers

PaiRec provides several specialized controllers:

```go
// From pairec.go - Route registration
Route("/api/recommend", &web.RecommendController{})      // Main recommendations
Route("/api/recall", &web.UserRecallController{})        // User-based recall
Route("/api/callback", &web.CallBackController{})        // Feedback logging
Route("/api/feature_reply", &web.FeatureReplyController{}) // Feature processing
Route("/api/embedding", &web.EmbeddingController{})      // Vector embeddings
```

### RecommendController Deep Dive

The main recommendation endpoint handles the core use case:

```go
type RecommendParam struct {
    SceneId  string                 `json:"scene_id"`  // Which scene to use
    Uid      string                 `json:"uid"`       // User identifier
    Size     int                    `json:"size"`      // Number of items wanted
    Features map[string]interface{} `json:"features"`  // Additional context
    Debug    bool                   `json:"debug"`     // Enable debug logging
}
```

**Processing Flow**:
1. Parse and validate JSON request
2. Create RecommendContext with user parameters
3. Load scene configuration
4. Execute recommendation service
5. Format and return results

```go
func (c *RecommendController) Process(w http.ResponseWriter, r *http.Request) {
    // 1. Parse request
    c.RequestBody, err = io.ReadAll(r.Body)
    err = json.Unmarshal(c.RequestBody, &c.param)
    
    // 2. Create context  
    c.context = context.NewRecommendContext()
    c.context.Param = &c.param
    
    // 3. Execute service
    recommendService := service.NewRecommendService(c.context)
    items := recommendService.Recommend()
    
    // 4. Return response
    response := RecommendResponse{Items: items}
    c.SendJSONResponse(w, response)
}
```

### Controller Architecture Pattern

All controllers follow a consistent pattern:

```go
type ControllerInterface interface {
    Process(http.ResponseWriter, *http.Request)
}

type Controller struct {
    Start       time.Time
    RequestBody []byte
}

func (c *Controller) SendJSONResponse(w http.ResponseWriter, data interface{}) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(data)
}
```

### Key Files
- **Base Controller**: `/web/controller.go` - Common functionality
- **Recommend API**: `/web/recommend_controller.go` - Main recommendation endpoint
- **Recall API**: `/web/user_recall_controller.go` - User recall endpoint
- **Features API**: `/web/feature_reply_controller.go` - Feature processing

---

## 4. Service Layer

**What it is**: The business logic layer that orchestrates recommendation workflows.

**Why it matters**: Services contain the core logic for how recommendations are generated and processed.

### Service Architecture

The service layer sits between controllers and the processing pipeline:

```
Controllers → Services → Processing Pipeline → Data Sources
     ↓           ↓              ↓                   ↓
Handle HTTP → Execute     → Recall/Filter     → MySQL/Redis/
Requests      Business      /Rank/Sort         HBase/etc.
              Logic         Pipeline
```

### Core Services

#### RecommendService
**Purpose**: Orchestrates the main recommendation workflow

```go
type RecommendService struct{}

// Main workflow methods
func (s *RecommendService) GetUID(context *RecommendContext) module.UID
func (s *RecommendService) Filter(user *User, items []*Item, context *RecommendContext) []*Item  
func (s *RecommendService) Sort(user *User, items []*Item, context *RecommendContext) []*Item
```

**Typical Usage Pattern**:
```go
service := &RecommendService{}

// 1. Get user information
userId := service.GetUID(context)
user := LoadUser(userId)

// 2. Generate candidate items (recall phase)
items := RecallItems(user, context)

// 3. Apply business rules (filter phase)  
filteredItems := service.Filter(user, items, context)

// 4. Rank and sort results (sort phase)
finalItems := service.Sort(user, filteredItems, context)
```

#### UserRecallService
**Purpose**: Handles user-based item recall and candidate generation

```go
type UserRecallService struct{}

func (s *UserRecallService) UserRecall(context *RecommendContext) []*module.Item {
    // Generate candidates using user profile
    // Apply recall algorithms (collaborative filtering, etc.)
    // Return candidate items for further processing
}
```

#### FeatureService
**Purpose**: Manages feature extraction and processing for ML models

### Service Registration Pattern

Services are registered during application startup:

```go
// From pairec.go
func runStartHook() {
    runBeforeStart()
    
    AddStartHook(func() error {
        service.Load(recconf.Config)           // Load core services
        feature.LoadFeatureConfig(recconf.Config) // Load feature processing
        general_rank.LoadGeneralRankWithConfig(recconf.Config) // Load ranking
        return nil
    })
}
```

### Context Flow Through Services

The `RecommendContext` flows through all service layers:

```go
type RecommendContext struct {
    RecommendId      string                    // Unique request ID
    Size             int                       // Requested result size
    Param            IParam                    // Request parameters
    Config           *recconf.RecommendConfig  // Configuration
    ExperimentResult *model.ExperimentResult   // A/B test results
    Debug            bool                      // Debug flag
    Log              []string                  // Request logging
}
```

### Key Files
- **Main Service**: `/service/recommend.go` - Core recommendation logic
- **Recall Service**: `/service/user_recall_service.go` - User-based recall
- **Service Loading**: `/service/` - Various service implementations
- **Context**: `/context/recommend_context.go` - Request context management

---

## 5. Processing Pipeline

**What it is**: The four-stage recommendation processing workflow: Recall → Filter → Rank → Sort.

**Why it matters**: This pipeline is the heart of PaiRec - understanding it is essential for building effective recommendation systems.

### The Four Stages

```
Input: User + Context → [Recall] → [Filter] → [Rank] → [Sort] → Output: Ranked Items
```

#### Stage 1: Recall
**Purpose**: Generate candidate items from various sources
**Input**: User profile, context parameters
**Output**: Large set of candidate items (typically 100-10,000)

**Example Recall Algorithms**:
- Collaborative Filtering: "Users like you also liked..."
- Content-Based: "Items similar to your history..."
- Popular Items: "Trending in your area..."
- Vector Similarity: "Semantically similar items..."

```go
// Recall configuration example
{
  "recall_names": ["collaborative_filtering", "popular_items", "vector_similarity"],
  "conf": {
    "recall_count": 1000  // Generate 1000 candidates
  }
}
```

#### Stage 2: Filter
**Purpose**: Apply business rules and constraints
**Input**: Candidate items from recall
**Output**: Filtered candidate items

**Example Filters**:
- Inventory Check: Remove out-of-stock items
- Quality Filter: Remove low-rated items  
- Diversity Filter: Ensure category diversity
- User Preferences: Apply user-specific rules

```go
func (s *RecommendService) Filter(user *module.User, items []*module.Item, context *context.RecommendContext) []*module.Item {
    filterData := filter.FilterData{
        Data: items, 
        Uid: user.Id, 
        Context: context, 
        User: user
    }
    
    filter.Filter(&filterData, "")
    return filterData.Data.([]*module.Item)
}
```

#### Stage 3: Rank  
**Purpose**: Score items using ML models
**Input**: Filtered candidate items
**Output**: Items with prediction scores

**Ranking Methods**:
- Deep Learning Models (TensorFlow, PyTorch)
- Gradient Boosting (XGBoost, LightGBM) 
- Linear Models with Feature Engineering
- Ensemble Methods

#### Stage 4: Sort
**Purpose**: Final ranking and optimization
**Input**: Scored items from ranking
**Output**: Final ordered recommendation list

**Sorting Strategies**:
- Score-based: Sort by prediction scores
- Business Rules: Boost certain categories
- Diversity Optimization: Ensure result variety
- Multi-objective: Balance multiple goals

```go
func (s *RecommendService) Sort(user *module.User, items []*module.Item, context *context.RecommendContext) []*module.Item {
    sortData := sort.SortData{
        Data: items, 
        Context: context, 
        User: user
    }
    
    sort.Sort(&sortData, "")
    return sortData.Data.([]*module.Item)
}
```

### Pipeline Configuration

Each scene defines its own pipeline:

```json
{
  "scene_id": "homepage",
  "recall_names": ["collaborative_filtering", "popular_items"],
  "filter_names": ["inventory_filter", "quality_filter"], 
  "sort_names": ["ml_ranking", "diversity_optimization"],
  "conf": {
    "recall_count": 1000,    // Candidates after recall
    "final_count": 50        // Final results after sort
  }
}
```

### Pipeline Execution Flow

```go
// Simplified pipeline execution
func RecommendationPipeline(user *User, context *RecommendContext) []*Item {
    // Stage 1: Recall
    candidates := ExecuteRecall(user, context)
    context.LogInfo(fmt.Sprintf("Recall generated %d candidates", len(candidates)))
    
    // Stage 2: Filter  
    filtered := ExecuteFilter(candidates, context)
    context.LogInfo(fmt.Sprintf("Filter left %d items", len(filtered)))
    
    // Stage 3: Rank
    ranked := ExecuteRank(filtered, context)
    context.LogInfo(fmt.Sprintf("Rank scored %d items", len(ranked)))
    
    // Stage 4: Sort
    final := ExecuteSort(ranked, context)
    context.LogInfo(fmt.Sprintf("Sort returned %d items", len(final)))
    
    return final
}
```

### Key Files
- **Recall**: `/service/recall/` - Recall algorithm implementations
- **Filter**: `/filter/` - Filtering logic and business rules  
- **Rank**: `/service/rank/` - ML model integration for ranking
- **Sort**: `/sort/` - Sorting algorithms and strategies
- **Pipeline**: `/service/pipeline/` - Pipeline orchestration

---

## 6. Data Sources & Persistence

**What it is**: Abstraction layer for accessing different types of data storage systems.

**Why it matters**: Recommendation systems require diverse data sources - user profiles, item catalogs, interaction logs, ML model features, etc.

### Supported Data Sources

PaiRec provides unified access to many storage systems:

#### Relational Databases
- **MySQL**: User profiles, item catalogs, business data
- **PostgreSQL**: Transactional data
- **Hologres**: Alibaba Cloud analytical database

#### NoSQL Databases  
- **Redis**: Caching, session storage, real-time features
- **HBase**: Large-scale structured data
- **TableStore**: Alibaba Cloud NoSQL
- **MongoDB**: Document-based storage

#### Analytical Stores
- **ClickHouse**: Time-series data, analytics
- **Apache Druid**: Real-time analytics

#### Specialized Systems
- **Kafka**: Stream processing, event logs
- **Milvus**: Vector similarity search
- **Feature Store**: Centralized feature management
- **Graph Database**: Relationship data

### Data Access Pattern

All data sources follow a consistent DAO (Data Access Object) pattern:

```go
// Example: User data access
type UserCollaborativeDao interface {
    LoadUserItems(user module.User) []*module.Item
    LoadUserFeatures(userId string) map[string]interface{}
}

// MySQL implementation
type UserCollaborativeMysqlDao struct {
    db *sql.DB
}

func (dao *UserCollaborativeMysqlDao) LoadUserItems(user module.User) []*module.Item {
    query := "SELECT item_id, score FROM user_items WHERE user_id = ?"
    rows, err := dao.db.Query(query, user.Id)
    // ... process results
    return items
}

// Redis implementation  
type UserCollaborativeRedisDao struct {
    client redis.Client
}

func (dao *UserCollaborativeRedisDao) LoadUserItems(user module.User) []*module.Item {
    key := fmt.Sprintf("user:items:%s", user.Id)
    data := dao.client.Get(key)
    // ... process cached data
    return items
}
```

### Configuration Example

Data sources are configured in the main config:

```json
{
  "dao_conf": {
    "mysql": [
      {
        "name": "user_db",
        "dsn": "user:pass@tcp(localhost:3306)/recommend?charset=utf8mb4",
        "max_open_conns": 50,
        "max_idle_conns": 10
      }
    ],
    "redis": [
      {
        "name": "cache", 
        "addr": "localhost:6379",
        "db_num": 0,
        "max_idle": 10,
        "max_active": 100
      }
    ],
    "clickhouse": [
      {
        "name": "analytics",
        "dsn": "tcp://localhost:9000?database=recommend"
      }
    ]
  }
}
```

### Data Source Loading

Data sources are initialized at startup:

```go
// From pairec.go
func runBeforeStart() {
    mysqldb.Load(recconf.Config)      // Load MySQL connections
    redisdb.Load(recconf.Config)      // Load Redis connections  
    clickhouse.Load(recconf.Config)   // Load ClickHouse connections
    hbase.Load(recconf.Config)        // Load HBase connections
    kafka.Load(recconf.Config)        // Load Kafka connections
    // ... other data sources
}
```

### Common Data Access Patterns

#### User Profile Loading
```go
// Load user from MySQL
userDao := module.NewUserCollaborativeMysqlDao("user_db")
user := userDao.LoadUser(userId)

// Load user features from Feature Store
featureDao := module.NewFeatureFeaturestoreDao("feature_store") 
features := featureDao.LoadUserFeatures(userId)
```

#### Item Retrieval
```go
// Load similar items from vector database
vectorDao := module.NewVectorDao("milvus")
similarItems := vectorDao.LoadSimilarItems(itemId, topK)

// Load item metadata from MySQL
itemDao := module.NewItemDao("product_db")
itemDetails := itemDao.LoadItemDetails(itemIds)
```

#### Real-time Features
```go
// Load real-time user behavior from Redis
realtimeDao := module.NewRealtimeUser2ItemDao("cache")
recentInteractions := realtimeDao.LoadRecentInteractions(userId)
```

### Key Files
- **Data Source Config**: `/persist/` - Database connection management
- **DAO Implementations**: `/module/` - Data access object implementations  
- **MySQL**: `/persist/mysqldb/` - MySQL connection handling
- **Redis**: `/persist/redisdb/` - Redis connection handling
- **ClickHouse**: `/persist/clickhouse/` - ClickHouse integration

---

## 7. Algorithm Integration

**What it is**: Integration layer for machine learning models and recommendation algorithms.

**Why it matters**: Modern recommendation systems rely heavily on ML models - understanding how PaiRec integrates with ML infrastructure is crucial.

### Supported ML Platforms

#### Cloud ML Services
- **EAS (Elastic Algorithm Service)**: Alibaba Cloud's ML model serving
- **TensorFlow Serving**: Google's production ML serving system
- **Seldon**: Multi-cloud ML deployment platform

#### Vector Search Systems  
- **Milvus**: Open-source vector similarity search
- **Faiss**: Facebook AI Similarity Search library

#### Model Formats
- **TensorFlow**: Deep learning models
- **PyTorch/TorchServe**: PyTorch model serving
- **ONNX**: Cross-platform model format
- **Scikit-learn**: Traditional ML models

### Algorithm Configuration

Algorithms are configured in the `algo_confs` section:

```json
{
  "algo_confs": [
    {
      "name": "deep_ctr_model",
      "type": "eas",
      "eas_conf": {
        "endpoint": "https://xxx.eas.aliyuncs.com/api/predict/ctr_model",
        "token": "your_token_here",
        "timeout": 100,
        "queue_name": "ctr_queue"
      }
    },
    {
      "name": "item_embedding",
      "type": "milvus", 
      "milvus_conf": {
        "host": "localhost",
        "port": 19530,
        "collection_name": "item_vectors"
      }
    }
  ]
}
```

### EAS (Elastic Algorithm Service) Integration

EAS is Alibaba Cloud's managed ML serving platform:

```go
// EAS client configuration
type EasConfig struct {
    Endpoint  string `json:"endpoint"`   // Model serving endpoint
    Token     string `json:"token"`      // Authentication token  
    Timeout   int    `json:"timeout"`    // Request timeout (ms)
    QueueName string `json:"queue_name"` // Request queue
}

// Making predictions
func PredictWithEAS(features []float32, config EasConfig) ([]float32, error) {
    client := eas.NewPredictClient(config.Endpoint, config.Token)
    
    request := &eas.PredictRequest{
        Features: features,
        Queue:    config.QueueName,
    }
    
    response, err := client.Predict(request)
    return response.Predictions, err
}
```

### TensorFlow Serving Integration

For self-hosted TensorFlow models:

```go
// TensorFlow Serving configuration  
type TFServingConfig struct {
    Host        string `json:"host"`
    Port        int    `json:"port"`
    ModelName   string `json:"model_name"`
    Signature   string `json:"signature"`
}

// Example prediction call
func PredictWithTensorFlow(features map[string]interface{}, config TFServingConfig) ([]float32, error) {
    client := tensorflow_serving.NewPredictClient(config.Host, config.Port)
    
    request := &tensorflow_serving.PredictRequest{
        ModelSpec: &tensorflow_serving.ModelSpec{
            Name:          config.ModelName,
            SignatureName: config.Signature,
        },
        Inputs: ConvertFeaturesToTensor(features),
    }
    
    response, err := client.Predict(request)
    return ExtractPredictions(response), err
}
```

### Vector Search Integration

For similarity-based recommendations:

```go
// Milvus vector search configuration
type MilvusConfig struct {
    Host           string `json:"host"`
    Port           int    `json:"port"`  
    CollectionName string `json:"collection_name"`
    MetricType     string `json:"metric_type"`     // L2, IP, COSINE
    TopK           int    `json:"top_k"`
}

// Search for similar items
func SearchSimilarItems(queryVector []float32, config MilvusConfig) ([]*module.Item, error) {
    client := milvus.NewClient(config.Host, config.Port)
    
    searchParams := milvus.SearchParam{
        CollectionName: config.CollectionName,
        QueryVectors:   [][]float32{queryVector},
        TopK:          config.TopK,
        MetricType:    config.MetricType,
    }
    
    results, err := client.Search(searchParams)
    return ConvertToItems(results), err
}
```

### Algorithm Usage in Pipeline

Algorithms are used throughout the recommendation pipeline:

#### Recall Stage
```go
// Collaborative filtering recall
collabFilter := algorithm.NewCollaborativeFilter("user_cf_model")
candidates := collabFilter.RecallItems(user, context)

// Vector similarity recall  
vectorSearch := algorithm.NewVectorSearch("item_embeddings")
similarItems := vectorSearch.FindSimilarItems(user.History, topK)
```

#### Ranking Stage
```go
// Deep learning ranking model
rankingModel := algorithm.NewEASModel("deep_ctr_model")
scores := rankingModel.PredictScores(items, user, context)

// Apply scores to items
for i, item := range items {
    item.Score = scores[i]
}
```

### Feature Engineering for ML Models

PaiRec provides feature engineering capabilities:

```go
// Feature extraction configuration
type FeatureConfig struct {
    Name     string            `json:"name"`
    Type     string            `json:"type"`        // "user", "item", "context"
    Source   string            `json:"source"`      // Data source name
    Features map[string]string `json:"features"`    // Feature definitions
}

// Example feature extraction
func ExtractFeatures(user *module.User, item *module.Item, context *context.RecommendContext) map[string]interface{} {
    features := make(map[string]interface{})
    
    // User features
    features["user_age"] = user.Age
    features["user_gender"] = user.Gender
    features["user_location"] = user.Location
    
    // Item features  
    features["item_category"] = item.Category
    features["item_price"] = item.Price
    features["item_rating"] = item.Rating
    
    // Context features
    features["hour_of_day"] = time.Now().Hour()
    features["day_of_week"] = int(time.Now().Weekday())
    
    return features
}
```

### Key Files
- **Algorithm Interface**: `/algorithm/` - Base algorithm interfaces
- **EAS Integration**: `/algorithm/eas/` - Alibaba Cloud EAS integration
- **TensorFlow**: `/algorithm/tfserving/` - TensorFlow Serving integration
- **Milvus**: `/algorithm/milvus/` - Vector search integration
- **Feature Engineering**: `/service/feature/` - Feature processing

---

## 8. Context & A/B Testing

**What it is**: Request context management and experimentation framework for testing different recommendation strategies.

**Why it matters**: Production recommendation systems need to track request state and experiment with different approaches to optimize performance.

### Request Context

The `RecommendContext` is the central object that flows through the entire request lifecycle:

```go
type RecommendContext struct {
    // Request identification
    RecommendId      string                    // Unique request ID
    ExpId            string                    // Experiment ID
    
    // Request parameters
    Size             int                       // Requested result count
    Debug            bool                      // Debug mode flag
    Param            IParam                    // Request parameters interface
    
    // Configuration & experiments
    Config           *recconf.RecommendConfig  // System configuration
    ExperimentResult *model.ExperimentResult   // A/B test configuration
    
    // Logging & monitoring
    Log              []string                  // Request-level logs
    contexParams     map[string]interface{}    // Additional context data
    mu               sync.RWMutex              // Thread safety
}
```

### Context Usage Patterns

#### Parameter Access
```go
// Access request parameters
userId := context.GetParameter("uid").(string)
sceneId := context.GetParameter("scene").(string) 
features := context.GetParameter("features").(map[string]interface{})

// Access nested parameters using JSON path
location := context.GetParameterByPath("features.location")
deviceType := context.GetParameterByPath("features.device.type")
```

#### Context Logging
```go
// Different logging levels
context.LogInfo("Starting recommendation pipeline")
context.LogWarning("Low inventory for popular items") 
context.LogError("Failed to load user profile")

// Debug logging (only when debug=true)
context.LogDebug("Candidate count after recall: 1000")
```

#### Context State Management
```go
// Store intermediate results
context.SetContextParam("recall_candidates", candidateItems)
context.SetContextParam("filter_result_count", len(filteredItems))

// Retrieve stored state
candidates := context.GetContextParam("recall_candidates").([]*module.Item)
```

### A/B Testing Framework

PaiRec provides a comprehensive A/B testing system for experimenting with different recommendation strategies:

#### Experiment Configuration

```json
{
  "abtest_conf": {
    "server": "https://abtest.example.com",
    "project_id": "recommendation_experiments",
    "experiments": [
      {
        "name": "ranking_algorithm_test",
        "traffic_split": 50,
        "variants": {
          "control": {
            "sort_names": ["traditional_ranking"]
          },
          "treatment": {
            "sort_names": ["deep_learning_ranking"]
          }
        }
      }
    ]
  }
}
```

#### Experiment Execution

```go
// A/B test integration in request flow
func ProcessRecommendation(context *RecommendContext) {
    // 1. Determine experiment assignment
    experimentResult := abtest.GetExperiment(context)
    context.ExperimentResult = experimentResult
    context.ExpId = experimentResult.ExperimentId
    
    // 2. Apply experiment configuration
    if experimentResult.Variant == "treatment" {
        // Use experimental algorithm
        context.Config = ApplyExperimentConfig(context.Config, experimentResult)
    }
    
    // 3. Log experiment assignment
    context.LogInfo(fmt.Sprintf("Experiment: %s, Variant: %s", 
        experimentResult.ExperimentName, experimentResult.Variant))
}
```

#### Traffic Splitting

```go
// Example traffic splitting logic
func DetermineExperimentVariant(userId string, experimentConfig ExperimentConfig) string {
    hash := HashUserId(userId)
    bucket := hash % 100
    
    if bucket < experimentConfig.TrafficSplit {
        return "treatment"
    } else {
        return "control"
    }
}
```

### Context Flow Through Pipeline

The context object carries information through every stage:

```
Request → Context Creation → Pipeline Execution → Response
    ↓           ↓                      ↓              ↓
Parse JSON → Initialize Context → Pass Through → Include Logs
Parameters   Set User/Scene ID     Each Stage     in Response
```

#### Context Initialization
```go
func NewRecommendContext() *RecommendContext {
    context := RecommendContext{
        Size:         -1,
        Debug:        false, 
        Log:          make([]string, 0, 16),
        contexParams: make(map[string]interface{}),
        RecommendId:  GenerateUniqueId(),
    }
    return &context
}
```

#### Context in Controllers
```go
func (c *RecommendController) Process(w http.ResponseWriter, r *http.Request) {
    // Create and populate context
    c.context = context.NewRecommendContext()
    c.context.Param = &c.param
    c.context.Size = c.param.Size
    c.context.Debug = c.param.Debug
    
    // Execute recommendation
    service := service.NewRecommendService(c.context)
    items := service.Recommend()
    
    // Include context logs in response
    response := RecommendResponse{
        Items: items,
        Debug: c.context.Log, // Include debug logs if enabled
    }
}
```

### Monitoring & Metrics

Context enables comprehensive monitoring:

#### Request Tracking
```go
// Each request gets unique tracking
context.LogInfo(fmt.Sprintf("requestId=%s\tscene=%s\tuid=%s", 
    context.RecommendId, context.GetParameter("scene"), context.GetParameter("uid")))
```

#### Performance Metrics  
```go
func MeasureStagePerformance(context *RecommendContext, stage string, fn func()) {
    start := time.Now()
    fn()
    duration := time.Since(start)
    
    context.LogInfo(fmt.Sprintf("stage=%s\tduration=%dms", stage, duration.Milliseconds()))
}
```

#### A/B Test Metrics
```go
// Log experiment outcomes for analysis
context.LogInfo(fmt.Sprintf("experiment=%s\tvariant=%s\tresult_count=%d\tresponse_time=%dms",
    context.ExperimentResult.ExperimentName,
    context.ExperimentResult.Variant, 
    len(results),
    responseTime))
```

### Key Files
- **Context Definition**: `/context/recommend_context.go` - Main context structure
- **A/B Testing**: `/abtest/` - Experiment management
- **Context Usage**: `/service/recommend.go` - Context flow in services
- **Controller Context**: `/web/recommend_controller.go` - Context in web layer

---

## Summary

You now understand the 8 key abstractions that form the foundation of PaiRec:

1. **Request Flow**: The complete user journey from API to response
2. **Configuration**: JSON-driven system behavior customization  
3. **Web Controllers**: HTTP API entry points and request handling
4. **Service Layer**: Business logic orchestration and workflow management
5. **Processing Pipeline**: The four-stage recommendation workflow (Recall → Filter → Rank → Sort)
6. **Data Sources**: Unified access to diverse storage systems
7. **Algorithm Integration**: ML model serving and recommendation algorithms
8. **Context & A/B Testing**: Request state management and experimentation

These abstractions work together to provide a flexible, scalable recommendation system that can be customized for different use cases through configuration rather than code changes.

## Related Documentation

For deeper exploration of PaiRec:

- **[Architecture Overview](ARCHITECTURE.md)**: Technical system design and component details
- **[Developer Guide](DEVELOPER_GUIDE.md)**: Step-by-step development setup and workflows  
- **[API Reference](API_REFERENCE.md)**: Complete API documentation with request/response examples
- **[Contributing Guide](CONTRIBUTING.md)**: How to contribute to the PaiRec project
- **[Examples](examples/)**: Real-world configuration examples for different use cases

## Next Steps

- **Explore Examples**: Check out `/examples/` for complete configuration examples
- **Read API Documentation**: See `API_REFERENCE.md` for detailed API specifications
- **Study Architecture**: Review `ARCHITECTURE.md` for deeper technical details
- **Follow Development Guide**: Use `DEVELOPER_GUIDE.md` to start contributing

The key to mastering PaiRec is understanding how these abstractions interact - each layer builds upon the previous ones to create a comprehensive recommendation system framework.