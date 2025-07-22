# PaiRec Recall Algorithms: Complete Technical Guide

This document provides a comprehensive, beginner-friendly guide to PaiRec's recall algorithms. We'll explore the recall system architecture, individual algorithm implementations, configuration patterns, and performance optimization techniques.

## Table of Contents

1. [Recall System Overview](#1-recall-system-overview)
2. [Core Architecture and Abstractions](#2-core-architecture-and-abstractions)
3. [Algorithm Categories](#3-algorithm-categories)
4. [Individual Algorithm Reference](#4-individual-algorithm-reference)
5. [Configuration and Integration](#5-configuration-and-integration)
6. [Performance and Optimization](#6-performance-and-optimization)
7. [Troubleshooting and Best Practices](#7-troubleshooting-and-best-practices)

---

## 1. Recall System Overview

### What is Recall?

**Recall** is the first and most crucial stage in PaiRec's recommendation pipeline. Its purpose is to efficiently generate a large set of candidate items (typically 100-10,000) from potentially millions of items in your catalog.

```
All Items (millions) → [Recall Stage] → Candidate Items (hundreds/thousands) → [Filter/Rank/Sort] → Final Results (10-100)
```

### Why Recall Matters

- **Efficiency**: Recall algorithms quickly narrow down the search space
- **Relevance**: Different algorithms capture different aspects of user preferences
- **Diversity**: Multiple recall sources ensure recommendation variety
- **Scalability**: Optimized algorithms handle large-scale item catalogs

### Recall in the Pipeline

```
User Request → Context Creation → Recall Execution → Filter → Rank → Sort → Response
     ↓              ↓                    ↓            ↓       ↓      ↓        ↓
Parse JSON → Load User Profile → Generate Candidates → Business Rules → ML Scoring → Final Ranking → JSON Response
```

**File Reference**: `/service/recall.go` - Main service orchestration

---

## 2. Core Architecture and Abstractions

### 2.1 The Recall Interface

Every recall algorithm implements a simple, unified interface:

```go
// File: /service/recall/recall.go
type Recall interface {
    GetCandidateItems(user *module.User, context *context.RecommendContext) []*module.Item
}
```

**Key Concept**: This interface abstracts away implementation details, allowing different algorithms to be used interchangeably.

### 2.2 BaseRecall Structure

All recall algorithms extend `BaseRecall`, which provides common functionality:

```go
// File: /service/recall/recall.go
type BaseRecall struct {
    modelName   string          // Unique identifier for this recall instance
    cache       cache.Cache     // Optional caching layer
    cachePrefix string          // Cache key prefix
    cacheTime   int             // Cache TTL in seconds
    itemType    string          // Type of items to return
    recallCount int             // Maximum number of candidates to generate
    recallAlgo  string          // Algorithm identifier
}
```

**Common Features Provided**:
- **Caching**: Automatic result caching with configurable TTL
- **Metrics**: Performance logging and timing
- **Configuration**: Standardized parameter handling

### 2.3 Algorithm Registration System

Recall algorithms are registered at system startup using a factory pattern:

```go
// File: /service/recall/recall.go  
func Load(config *recconf.RecommendConfig) {
    for _, conf := range config.RecallConfs {
        var recall Recall
        if conf.RecallType == "UserCollaborativeFilterRecall" {
            recall = NewUserCollaborativeFilterRecall(conf)
        } else if conf.RecallType == "VectorRecall" {
            recall = NewVectorRecall(conf)
        }
        // ... more algorithm types
        
        RegisterRecall(conf.Name, recall)
    }
}
```

**Key Concept**: This registration system allows dynamic algorithm loading based on configuration.

### 2.4 Data Access Objects (DAOs)

Recall algorithms use DAOs to access different data sources:

```go
// Examples of DAO interfaces
type UserCollaborativeDao interface {
    ListItemsByUser(user *User, context *RecommendContext) []*Item
}

type VectorDao interface {
    VectorString(userId string) (string, error)
}

type ItemCollaborativeDao interface {
    ListItemsByItem(user *User, context *RecommendContext) []*Item
}
```

**Supported Data Sources**:
- **MySQL**: Structured user/item data
- **Redis**: Cached precomputed results
- **HBase**: Large-scale interaction data
- **ClickHouse**: Analytics and aggregated data
- **Hologres**: Alibaba Cloud analytical database
- **Vector Databases**: Milvus, Faiss for similarity search

---

## 3. Algorithm Categories

PaiRec implements four main categories of recall algorithms:

### 3.1 Collaborative Filtering
**Principle**: "Users with similar preferences like similar items"

**Algorithms**:
- `UserCollaborativeFilterRecall`: User-based collaborative filtering
- `ItemCollaborativeFilterRecall`: Item-based collaborative filtering

**Use Cases**: E-commerce, content platforms, social networks

### 3.2 Content-Based Filtering
**Principle**: "Recommend items similar to user's historical preferences"

**Algorithms**:
- `VectorRecall`: Vector similarity based on item/user embeddings
- `HologresVectorRecall`: Vector search using Hologres database
- `OnlineVectorRecall`: Real-time vector similarity

**Use Cases**: News, articles, product catalogs with rich metadata

### 3.3 Popularity-Based
**Principle**: "Recommend trending or popular items"

**Algorithms**:
- `UserGlobalHotRecall`: Globally trending items
- `UserGroupHotRecall`: Popular items within user groups

**Use Cases**: Cold start scenarios, trending content, seasonal items

### 3.4 Hybrid and Advanced
**Principle**: "Combine multiple signals for better recommendations"

**Algorithms**:
- `BeRecall`: Backend service integration
- `GraphRecall`: Graph-based recommendations
- `RealTimeU2IRecall`: Real-time user-to-item patterns
- `ColdStartRecall`: New user/item handling

**Use Cases**: Complex recommendation scenarios, real-time systems

---

## 4. Individual Algorithm Reference

### 4.1 UserCollaborativeFilterRecall

**File**: `/service/recall/user_collaborative_filter_recall.go`

**Algorithm Overview**:
User-based collaborative filtering finds users with similar behavior patterns and recommends items those similar users liked.

**How It Works**:
1. Load user's interaction history
2. Find users with similar interaction patterns
3. Recommend items liked by similar users
4. Sort by similarity score

**Implementation Details**:
```go
type UserCollaborativeFilterRecall struct {
    *BaseRecall
    userCollaborativeDao module.UserCollaborativeDao
}

func (r *UserCollaborativeFilterRecall) GetCandidateItems(user *module.User, context *context.RecommendContext) []*module.Item {
    // 1. Check cache first
    if cachedItems := r.checkCache(user.Id); cachedItems != nil {
        return cachedItems
    }
    
    // 2. Load collaborative filtering results from DAO
    items := r.userCollaborativeDao.ListItemsByUser(user, context)
    
    // 3. Sort by score (similarity/relevance)
    sort.Sort(sort.Reverse(psort.ItemScoreSlice(items)))
    
    // 4. Limit to configured count
    if r.recallCount < len(items) {
        items = items[:r.recallCount]
    }
    
    // 5. Cache results for future requests
    r.cacheResults(user.Id, items)
    
    return items
}
```

**Configuration Example**:
```json
{
  "name": "user_cf",
  "recall_type": "UserCollaborativeFilterRecall",
  "recall_count": 500,
  "item_type": "product",
  "dao_conf": {
    "adapter": "mysql",
    "dsn": "user:pass@tcp(localhost:3306)/recommend"
  },
  "cache_adapter": "redis",
  "cache_prefix": "user_cf:",
  "cache_time": 1800
}
```

**When to Use**:
- ✅ Rich user interaction data available
- ✅ User behavior patterns are consistent
- ✅ Want to discover new items through user similarity
- ❌ Cold start scenarios (new users)
- ❌ Sparse interaction data

### 4.2 VectorRecall

**File**: `/service/recall/vector_recall.go`

**Algorithm Overview**:
Vector-based recall uses embedding representations to find items similar to user preferences through vector similarity.

**How It Works**:
1. Load user embedding vector from DAO
2. Perform similarity search against item vectors
3. Return most similar items with similarity scores

**Implementation Details**:
```go
type VectorRecall struct {
    *BaseRecall
    dao module.VectorDao  // Handles vector storage and retrieval
}

func (r *VectorRecall) GetCandidateItems(user *module.User, context *context.RecommendContext) []*module.Item {
    // 1. Get user vector representation
    userVectorString, err := r.dao.VectorString(string(user.Id))
    if err != nil {
        return nil
    }
    
    // 2. Parse vector string into float array
    userVector := parseVectorString(userVectorString)
    
    // 3. Create similarity search request
    request := pai_web.VectorRequest{
        K: uint32(r.recallCount),
        Vector: userVector,
    }
    
    // 4. Execute vector similarity search
    result, err := algorithm.Run(r.recallAlgo, &request)
    if err != nil {
        return nil
    }
    
    // 5. Convert results to Item objects
    reply := result.(*pai_web.VectorReply)
    items := make([]*module.Item, len(reply.Labels))
    for i, itemId := range reply.Labels {
        item := module.NewItem(itemId)
        item.Score = float64(reply.Scores[i])  // Similarity score
        item.RetrieveId = r.modelName
        items[i] = item
    }
    
    return items
}
```

**Configuration Example**:
```json
{
  "name": "item_vector_recall",
  "recall_type": "VectorRecall", 
  "recall_count": 1000,
  "recall_algo": "faiss_index",
  "item_type": "article",
  "dao_conf": {
    "adapter": "mysql",
    "vector_table": "user_embeddings"
  }
}
```

**When to Use**:
- ✅ Rich item metadata or content
- ✅ Pre-trained embedding models available
- ✅ Content-based similarity important
- ✅ Good for cold start scenarios
- ❌ Limited content features
- ❌ Computational cost concerns

### 4.3 ItemCollaborativeFilterRecall

**File**: `/service/recall/item_collaborative_filter_recall.go`

**Algorithm Overview**:
Item-based collaborative filtering recommends items similar to those the user has interacted with.

**How It Works**:
1. Analyze user's interaction history
2. Find items similar to user's preferred items
3. Recommend items with high item-to-item similarity

**Implementation Details**:
```go
type ItemCollaborativeFilterRecall struct {
    *BaseRecall
    itemCollaborativeDao module.ItemCollaborativeDao
}

func (r *ItemCollaborativeFilterRecall) GetCandidateItems(user *module.User, context *context.RecommendContext) []*module.Item {
    // Load items similar to user's historical items
    return r.itemCollaborativeDao.ListItemsByItem(user, context)
}
```

**When to Use**:
- ✅ Item relationships are stable
- ✅ "Customers who bought X also bought Y" scenarios
- ✅ Rich item interaction data
- ✅ Good recommendation explanations ("Because you liked X")

### 4.4 UserGlobalHotRecall

**File**: `/service/recall/user_global_hot_recall.go`

**Algorithm Overview**:
Recommends globally popular or trending items across all users.

**Implementation Details**:
```go
type UserGlobalHotRecall struct {
    *BaseRecall
    userGroupHotRecallDao module.UserGlobalHotRecallDao
}

func (r *UserGlobalHotRecall) GetCandidateItems(user *module.User, context *context.RecommendContext) []*module.Item {
    // Note: Uses model name as cache key (global, not user-specific)
    key := r.modelName
    
    if cachedItems := r.checkGlobalCache(key); cachedItems != nil {
        return cachedItems
    }
    
    // Load global hot items
    items := r.userGroupHotRecallDao.ListItemsByUser(user, context)
    
    // Cache globally (shared across users)
    r.cacheGlobalResults(key, items)
    
    return items
}
```

**When to Use**:
- ✅ Cold start scenarios (new users)
- ✅ Trending content promotion
- ✅ Fallback when personalized algorithms fail
- ✅ Seasonal or event-driven recommendations

### 4.5 HologresVectorRecall

**File**: `/service/recall/hologres_vector_recall.go`

**Algorithm Overview**:
Advanced vector similarity search using Alibaba Cloud's Hologres database with optimized vector operations.

**Key Features**:
- SQL-based vector similarity queries
- Built-in distance functions
- High-performance vector indexing
- Real-time vector updates

**Implementation Highlights**:
```go
type HologresVectorRecall struct {
    *BaseRecall
    db                   *sql.DB
    vectorEmbeddingField string  // Vector column name
    vectorKeyField       string  // Primary key column  
    table                string  // Vector table name
    sql                  string  // Precompiled SQL query
}

// SQL template for vector similarity
var hologres_vector_sql = "SELECT %s, pm_approx_inner_product_distance(%s,$1) as distance FROM %s %s ORDER BY distance desc limit %d"
```

**When to Use**:
- ✅ Large-scale vector databases (millions of vectors)
- ✅ Need SQL-based vector operations
- ✅ Using Alibaba Cloud infrastructure
- ✅ Real-time vector updates required

### 4.6 BeRecall (Backend Service Recall)

**File**: `/service/recall/be_recall.go`

**Algorithm Overview**:
Integrates with external backend services that provide pre-computed recommendations.

**Architecture**:
- Delegates recall computation to external services
- Handles service discovery and load balancing
- Provides unified interface for external algorithms

**When to Use**:
- ✅ Complex algorithms not suitable for real-time computation
- ✅ Integration with existing recommendation services
- ✅ Microservices architecture
- ✅ Pre-computed recommendation batches

---

## 5. Configuration and Integration

### 5.1 Configuration Structure

Recall algorithms are configured in the `recall_confs` section:

```json
{
  "recall_confs": [
    {
      "name": "collaborative_filter",           // Unique identifier
      "recall_type": "UserCollaborativeFilterRecall",  // Algorithm type
      "recall_count": 500,                      // Max candidates
      "item_type": "product",                   // Item category
      "dao_conf": {                            // Data source config
        "adapter": "mysql",
        "dsn": "user:pass@tcp(localhost:3306)/recommend",
        "table": "user_cf_results"
      },
      "cache_adapter": "redis",                 // Cache configuration
      "cache_prefix": "cf:",
      "cache_time": 1800                        // 30 minutes
    }
  ]
}
```

### 5.2 Scene Configuration

Different scenarios use different recall combinations:

```json
{
  "scene_confs": [
    {
      "scene_id": "homepage",
      "recall_names": [
        "collaborative_filter",
        "popular_items", 
        "vector_similarity"
      ],
      "conf": {
        "recall_count": 1000,     // Total candidates across all algorithms
        "final_count": 50         // Final results after filtering/ranking
      }
    },
    {
      "scene_id": "product_detail", 
      "recall_names": [
        "item_collaborative_filter",
        "similar_products"
      ]
    }
  ]
}
```

### 5.3 Multiple Algorithm Execution

PaiRec executes multiple recall algorithms concurrently:

```go
// File: /service/recall.go
func (s *RecallService) GetItems(user *module.User, context *context.RecommendContext) []*module.Item {
    recalls := loadConfiguredRecalls(context)
    
    // Execute algorithms concurrently
    ch := make(chan []*module.Item, len(recalls))
    
    for _, recall := range recalls {
        go func(recall Recall) {
            defer recoverFromPanic()
            items := recall.GetCandidateItems(user, context)
            ch <- items
        }(recall)
    }
    
    // Collect and merge results
    var allItems []*module.Item
    for i := 0; i < len(recalls); i++ {
        items := <-ch
        allItems = append(allItems, items...)
    }
    
    return allItems
}
```

### 5.4 A/B Testing Integration

Recall algorithms can be configured differently for experiments:

```json
{
  "abtest_conf": {
    "experiments": [
      {
        "name": "recall_algorithm_test",
        "variants": {
          "control": {
            "recall_names": ["collaborative_filter", "popular_items"]
          },
          "treatment": {
            "recall_names": ["vector_similarity", "graph_based"]
          }
        }
      }
    ]
  }
}
```

---

## 6. Performance and Optimization

### 6.1 Caching Strategies

#### Algorithm-Level Caching
Each recall algorithm can implement its own caching:

```go
// Cache key patterns
userSpecificCache := "cf:" + userId        // User-specific results
globalCache := "hot_items"                 // Shared across users
timeBasedCache := "trending:" + hour       // Time-sensitive data
```

#### Cache Configuration
```json
{
  "cache_adapter": "redis",
  "cache_prefix": "recall:",
  "cache_time": 1800,          // 30 minutes
  "cache_config": {
    "max_idle": 10,
    "max_active": 100,
    "idle_timeout": 300
  }
}
```

### 6.2 Performance Monitoring

PaiRec provides comprehensive performance metrics:

```go
// Timing metrics for each algorithm
log.Info(fmt.Sprintf("requestId=%s\tmodule=VectorRecall\tname=%s\tcount=%d\tcost=%d", 
    context.RecommendId, r.modelName, len(results), utils.CostTime(start)))
```

**Key Metrics to Monitor**:
- **Response Time**: Per algorithm and total recall time
- **Cache Hit Rate**: Percentage of requests served from cache
- **Result Count**: Number of candidates generated per algorithm
- **Error Rate**: Failed recall requests

### 6.3 Optimization Best Practices

#### 1. Algorithm Selection
- **Fast algorithms first**: Place quick algorithms before expensive ones
- **Diversify sources**: Use complementary algorithms for better coverage
- **Fallback chains**: Always include a fast fallback (e.g., popular items)

#### 2. Caching Strategy
```go
// Optimize cache usage based on algorithm characteristics
if isUserSpecific(algorithm) {
    cacheKey = algorithm + ":" + userId
    cacheTTL = 30 * time.Minute
} else if isGlobal(algorithm) {
    cacheKey = algorithm + ":global"  
    cacheTTL = 60 * time.Minute
}
```

#### 3. Database Optimization
- **Connection Pooling**: Configure appropriate pool sizes
- **Query Optimization**: Use indexes on user_id, item_id columns
- **Batch Processing**: Pre-compute results for popular queries

#### 4. Concurrent Execution
```go
// Execute algorithms in parallel with timeout
ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
defer cancel()

go func() {
    select {
    case result := <-algorithmResult:
        // Process result
    case <-ctx.Done():
        // Handle timeout
    }
}()
```

### 6.4 Scaling Considerations

#### Horizontal Scaling
- **Stateless Design**: Keep algorithms stateless for easy scaling
- **External Caching**: Use Redis for shared caching across instances
- **Database Read Replicas**: Distribute read load across multiple databases

#### Data Partitioning
```go
// Example: Partition users by hash for distributed processing
func getPartition(userId string) int {
    hash := md5.Sum([]byte(userId))
    return int(hash[0]) % numPartitions
}
```

---

## 7. Troubleshooting and Best Practices

### 7.1 Common Issues and Solutions

#### Issue: High Response Times
**Symptoms**: Recall taking >100ms per request
**Causes & Solutions**:
- ❌ **No caching**: Enable Redis caching with appropriate TTL
- ❌ **Database bottleneck**: Optimize queries, add indexes, use connection pooling
- ❌ **Too many algorithms**: Reduce concurrent algorithms or add timeouts
- ❌ **Large result sets**: Limit recall_count in configuration

#### Issue: Poor Recommendation Quality
**Symptoms**: Low click-through rates, poor user engagement
**Causes & Solutions**:
- ❌ **Algorithm mismatch**: Choose appropriate algorithms for your use case
- ❌ **Stale data**: Reduce cache TTL, implement real-time data updates
- ❌ **Insufficient diversity**: Add multiple algorithm types
- ❌ **Cold start problems**: Implement fallback to popular items

#### Issue: Memory Issues
**Symptoms**: Out of memory errors, high memory usage
**Causes & Solutions**:
- ❌ **Large vectors**: Use dimension reduction or sparse representations
- ❌ **No result limiting**: Configure appropriate recall_count
- ❌ **Memory leaks**: Ensure proper resource cleanup in DAOs

### 7.2 Development Best Practices

#### 1. Algorithm Implementation
```go
// Always implement proper error handling
func (r *CustomRecall) GetCandidateItems(user *module.User, context *context.RecommendContext) []*module.Item {
    start := time.Now()
    defer func() {
        // Log performance metrics
        log.Info(fmt.Sprintf("requestId=%s\tmodule=%s\tcost=%d", 
            context.RecommendId, "CustomRecall", utils.CostTime(start)))
    }()
    
    // Validate inputs
    if user == nil || user.Id == "" {
        log.Error("Invalid user provided to recall algorithm")
        return nil
    }
    
    // Your algorithm implementation
    items, err := r.dao.LoadItems(user, context)
    if err != nil {
        log.Error(fmt.Sprintf("Error loading items: %v", err))
        return nil
    }
    
    return items
}
```

#### 2. Configuration Validation
```go
// Validate configuration at startup
func NewCustomRecall(config recconf.RecallConfig) *CustomRecall {
    if config.RecallCount <= 0 {
        panic("recall_count must be positive")
    }
    if config.DaoConf.Adapter == "" {
        panic("dao adapter must be specified")
    }
    
    return &CustomRecall{
        BaseRecall: NewBaseRecall(config),
        dao: module.NewCustomDao(config),
    }
}
```

#### 3. Testing Strategy
```go
// Example test structure
func TestCustomRecall(t *testing.T) {
    // Setup test data
    user := &module.User{Id: "test_user"}
    context := &context.RecommendContext{RecommendId: "test_req"}
    
    // Mock DAO
    mockDao := &MockCustomDao{}
    recall := &CustomRecall{dao: mockDao}
    
    // Test normal case
    items := recall.GetCandidateItems(user, context)
    assert.NotNil(t, items)
    assert.True(t, len(items) > 0)
    
    // Test error cases
    items = recall.GetCandidateItems(nil, context)
    assert.Nil(t, items)
}
```

### 7.3 Monitoring and Alerting

#### Key Metrics to Monitor
1. **Response Time**: P50, P95, P99 latency per algorithm
2. **Success Rate**: Percentage of successful recall requests
3. **Cache Hit Rate**: Effectiveness of caching strategy
4. **Result Quality**: CTR, conversion rates from recall candidates

#### Example Monitoring Configuration
```json
{
  "metrics": {
    "recall_latency": {
      "type": "histogram",
      "labels": ["algorithm", "scene"]
    },
    "recall_success_rate": {
      "type": "counter", 
      "labels": ["algorithm", "error_type"]
    },
    "cache_hit_rate": {
      "type": "gauge",
      "labels": ["algorithm", "cache_type"]
    }
  }
}
```

---

## Summary

This guide covered the complete PaiRec recall system:

1. **System Overview**: Understanding recall's role in the recommendation pipeline
2. **Core Architecture**: Interfaces, base classes, and registration systems
3. **Algorithm Categories**: Collaborative filtering, content-based, popularity, and hybrid approaches
4. **Individual Algorithms**: Detailed implementation analysis for each recall type
5. **Configuration**: How to configure and integrate multiple algorithms
6. **Performance**: Optimization strategies and scaling considerations
7. **Best Practices**: Development guidelines and troubleshooting tips

### Key Takeaways

- **Modular Design**: The recall interface allows easy algorithm swapping and testing
- **Multi-Algorithm**: Use multiple complementary algorithms for better coverage
- **Caching is Critical**: Implement appropriate caching strategies for performance
- **Monitor Everything**: Track performance, quality, and system health metrics
- **Configuration-Driven**: Leverage PaiRec's flexible configuration system

### Next Steps

1. **Start Simple**: Implement basic collaborative filtering or popular items
2. **Add Caching**: Configure Redis caching for performance
3. **Experiment**: Use A/B testing to compare algorithm performance
4. **Monitor**: Set up metrics and alerting for production deployment
5. **Optimize**: Fine-tune based on real user behavior and system metrics

For more information, see:
- [Architecture Overview](ARCHITECTURE.md) - System design details
- [Tutorial](TUTORIAL.md) - Complete PaiRec tutorial
- [API Reference](API_REFERENCE.md) - API documentation
- [Examples](examples/) - Sample configurations and use cases