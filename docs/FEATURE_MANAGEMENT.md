# Feature Management

Deep dive into how PaiRec handles user and item features with thread safety, caching, and async loading.

## Overview

Feature management is a critical component of recommendation systems. PaiRec's feature management system provides:

- **Thread-safe** property access and modification
- **Asynchronous loading** for non-blocking feature retrieval  
- **Multi-source caching** for performance optimization
- **Type-safe access** with automatic conversions
- **Dynamic feature addition** during request processing

## 🏗️ Feature Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                   Application Layer                        │
│           Services requesting features                     │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                Feature Management Layer                    │
│     User.Properties • Item.Properties • Type Safety       │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                   Caching Layer                            │
│    CacheFeatures • AsyncLoading • Sync Mechanisms         │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                  Feature DAOs                              │
│   MySQL • Redis • FeatureStore • HBase • ClickHouse       │
└─────────────────────────────────────────────────────────────┘
```

## 👤 User Feature Management

### Property Storage and Access

**Thread-Safe Property Management**

```go
type User struct {
    mutex      sync.RWMutex
    Properties map[string]interface{}
    // ... other fields
}

// Safe concurrent property operations
func (u *User) AddProperty(key string, value interface{}) {
    u.mutex.Lock()
    defer u.mutex.Unlock()
    u.Properties[key] = value
}

func (u *User) GetProperty(key string) interface{} {
    u.mutex.RLock()
    defer u.mutex.RUnlock()
    return u.Properties[key]
}
```

### Type-Safe Property Access

The system provides type-safe getters with automatic conversion:

```go
// String property access
func (u *User) StringProperty(key string) string {
    u.mutex.RLock()
    defer u.mutex.RUnlock()
    val, ok := u.Properties[key]
    if !ok {
        return ""
    }

    switch value := val.(type) {
    case string:
        return value
    case int:
        return strconv.Itoa(value)
    case float64:
        return strconv.FormatFloat(value, 'f', -1, 64)
    case int32:
        return strconv.Itoa(int(value))
    case int64:
        return strconv.Itoa(int(value))
    }
    return ""
}

// Float property access with error handling
func (u *User) FloatProperty(key string) (float64, error) {
    u.mutex.RLock()
    defer u.mutex.RUnlock()
    val, ok := u.Properties[key]
    if !ok {
        return float64(0), errors.New("property key not exist")
    }

    switch value := val.(type) {
    case float64:
        return value, nil
    case int:
        return float64(value), nil
    case string:
        f, err := strconv.ParseFloat(value, 64)
        return f, err
    default:
        return float64(0), errors.New("unsupported type")
    }
}
```

### Batch Property Operations

```go
// Add multiple properties atomically
func (u *User) AddProperties(properties map[string]interface{}) {
    u.mutex.Lock()
    defer u.mutex.Unlock()
    for key, val := range properties {
        u.Properties[key] = val
    }
}

// Delete multiple properties atomically
func (u *User) DeleteProperties(features []string) {
    u.mutex.Lock()
    defer u.mutex.Unlock()
    for _, key := range features {
        delete(u.Properties, key)
    }
}
```

## 🗄️ Multi-Source Feature Caching

### Cache Architecture

Users maintain separate cache spaces for different feature sources:

```go
type User struct {
    cacheFeatures map[string]map[string]any // namespace -> features
    // ... other fields
}

// Add features to a specific cache namespace
func (u *User) AddCacheFeatures(key string, features map[string]any) {
    u.mutex.Lock()
    defer u.mutex.Unlock()
    
    m, ok := u.cacheFeatures[key]
    if !ok {
        m = make(map[string]any, len(features))
    }

    for k, v := range features {
        m[k] = v
    }
    u.cacheFeatures[key] = m
}

// Load cached features into main properties
func (u *User) LoadCacheFeatures(key string) {
    u.mutex.Lock()
    defer u.mutex.Unlock()
    
    if m, ok := u.cacheFeatures[key]; ok {
        for k, v := range m {
            u.Properties[k] = v
        }
    }
}
```

### Cache Usage Patterns

```go
// Pattern 1: Pre-populate cache from expensive source
user := NewUser("user123")

// Load from ML model (expensive)
mlFeatures := map[string]any{
    "user_embedding": []float64{0.1, 0.2, 0.3},
    "predicted_category": "electronics",
    "engagement_score": 0.85,
}
user.AddCacheFeatures("ml_model", mlFeatures)

// Load from behavior analysis (expensive)
behaviorFeatures := map[string]any{
    "session_duration": 1200,
    "pages_viewed": 15,
    "bounce_rate": 0.2,
}
user.AddCacheFeatures("behavior_analysis", behaviorFeatures)

// Later: Load specific cache when needed
user.LoadCacheFeatures("ml_model")
```

## ⚡ Asynchronous Feature Loading

### Async Loading Architecture

The system supports non-blocking feature loading with synchronization:

```go
type User struct {
    featureAsyncLoadCount    int32           // Atomic counter
    featureAsyncLoadCh       chan struct{}   // Completion signal
    featureAsyncLoadChClosed bool           // Channel state
    // ... other fields
}
```

### Async Loading Pattern

```go
// Start async feature loading
func StartAsyncFeatureLoading(user *User, context *context.RecommendContext) {
    // Increment counter for each async operation
    user.IncrementFeatureAsyncLoadCount(2) // 2 async operations
    
    // Async operation 1: Load user behavior features
    go func() {
        defer user.DescFeatureAsyncLoadCount(1)
        
        behaviorFeatures := loadUserBehaviorFeatures(user.Id)
        user.AddCacheFeatures("behavior", behaviorFeatures)
    }()
    
    // Async operation 2: Load ML model features  
    go func() {
        defer user.DescFeatureAsyncLoadCount(1)
        
        mlFeatures := callMLModelService(user.Id)
        user.AddCacheFeatures("ml_model", mlFeatures)
    }()
}

// Wait for async loading to complete (with timeout)
func WaitForFeatureLoading(user *User, timeout time.Duration) {
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()
    
    select {
    case <-user.FeatureAsyncLoadCh():
        // All async operations completed
        user.LoadCacheFeatures("behavior")
        user.LoadCacheFeatures("ml_model")
    case <-ctx.Done():
        // Timeout - proceed with partial features
        log.Warning("Feature loading timeout")
    }
}
```

### Counter Management

```go
// Increment async operation counter
func (u *User) IncrementFeatureAsyncLoadCount(count int32) {
    atomic.AddInt32(&u.featureAsyncLoadCount, count)
}

// Decrement counter and signal completion when reaching zero
func (u *User) DescFeatureAsyncLoadCount(count int32) {
    u.mutex.Lock()
    defer u.mutex.Unlock()
    
    if atomic.LoadInt32(&u.featureAsyncLoadCount) < 1 {
        panic("featureAsyncLoadCount not less than 0")
    }
    
    curr := atomic.AddInt32(&u.featureAsyncLoadCount, -1*count)
    if curr == 0 {
        if !u.featureAsyncLoadChClosed {
            close(u.featureAsyncLoadCh)
            u.featureAsyncLoadChClosed = true
        }
    }
}
```

## 📦 Item Feature Management

### Item Property System

Items have similar thread-safe property management:

```go
type Item struct {
    mutex      sync.RWMutex
    Properties map[string]interface{}
    algoScores map[string]float64
    // ... other fields
}

// Thread-safe property operations
func (t *Item) AddProperty(key string, value interface{}) {
    t.mutex.Lock()
    defer t.mutex.Unlock()
    t.Properties[key] = value
}

func (t *Item) GetProperty(key string) interface{} {
    t.mutex.RLock()
    defer t.mutex.RUnlock()
    return t.Properties[key]
}
```

### Algorithm Score Management

Items track scores from multiple algorithms:

```go
// Add score from specific algorithm
func (t *Item) AddAlgoScore(name string, score float64) {
    t.mutex.Lock()
    defer t.mutex.Unlock()

    if t.algoScores == nil {
        t.algoScores = make(map[string]float64)
    }
    t.algoScores[name] = score
}

// Get score from specific algorithm
func (t *Item) GetAlgoScore(key string) float64 {
    t.mutex.RLock()
    defer t.mutex.RUnlock()
    return t.algoScores[key]
}

// Increment existing score (for ensemble methods)
func (t *Item) IncrAlgoScore(name string, score float64) {
    t.mutex.Lock()
    defer t.mutex.Unlock()

    if t.algoScores == nil {
        t.algoScores = make(map[string]float64)
    }
    t.algoScores[name] += score
}
```

### Feature Processing for ML Models

Items provide different feature representations for various use cases:

```go
// Get all features including recall information
func (t *Item) GetFeatures() map[string]interface{} {
    t.mutex.Lock()
    defer t.mutex.Unlock()

    // Add recall context if present
    if t.RetrieveId != "" {
        if _, ok := t.Properties[t.RetrieveId]; !ok {
            t.Properties[t.RetrieveId] = t.Score
            t.Properties["recall_name"] = t.RetrieveId
            t.Properties["recall_score"] = t.Score
        }
    }

    features := make(map[string]interface{}, len(t.Properties))
    for k, v := range t.Properties {
        features[k] = v
    }
    return features
}

// Get expression data (properties + algorithm scores)
func (t *Item) ExprData() map[string]any {
    ret := make(map[string]any, len(t.algoScores)+len(t.Properties))

    t.mutex.RLock()
    defer t.mutex.RUnlock()
    
    // Include algorithm scores
    for k, v := range t.algoScores {
        ret[k] = v
    }

    // Include properties
    for k, v := range t.Properties {
        ret[k] = v
    }

    return ret
}
```

## 🔧 Feature DAO Integration

### Base Feature DAO

All feature DAOs extend a common base:

```go
type FeatureBaseDao struct {
    featureStore              string
    loadFromCacheFeaturesName string
    // ... configuration fields
}

func NewFeatureBaseDao(config *recconf.FeatureDaoConfig) *FeatureBaseDao {
    return &FeatureBaseDao{
        featureStore:              config.FeatureStore,
        loadFromCacheFeaturesName: config.LoadFromCacheFeaturesName,
    }
}
```

### Feature Loading Pattern

```go
// Standard feature DAO implementation pattern
func (d *FeatureMysqlDao) FeatureFetch(user *User, items []*Item, context *context.RecommendContext) {
    // Handle user features
    if d.featureStore == Feature_Store_User {
        d.userFeatureFetch(user, context)
    }
    
    // Handle item features  
    if d.featureStore == Feature_Store_Item {
        d.itemFeatureFetch(items, context)
    }
}

func (d *FeatureMysqlDao) userFeatureFetch(user *User, context *context.RecommendContext) {
    // Check if should load from cache first
    if d.loadFromCacheFeaturesName != "" {
        ctx, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
        defer cancel()
        
        select {
        case <-user.FeatureAsyncLoadCh():
            user.LoadCacheFeatures(d.loadFromCacheFeaturesName)
            return
        case <-ctx.Done():
            log.Warning("Cache feature loading timeout")
        }
    }
    
    // Load from database
    query := fmt.Sprintf("SELECT feature_name, feature_value FROM %s WHERE user_id = ?", d.table)
    rows, err := d.db.Query(query, user.Id)
    if err != nil {
        return
    }
    defer rows.Close()
    
    features := make(map[string]interface{})
    for rows.Next() {
        var name, value string
        rows.Scan(&name, &value)
        features[name] = value
    }
    
    user.AddProperties(features)
}
```

## 🎯 Specialized Feature Types

### Embedding Features

Special handling for embedding vectors:

```go
// Extract embedding features from user properties
func (u *User) GetEmbeddingFeature() (features map[string]interface{}) {
    u.mutex.RLock()
    defer u.mutex.RUnlock()
    
    features = make(map[string]interface{})
    for k, v := range u.Properties {
        if strings.HasSuffix(k, "embedding") {
            if emb, ok := v.(string); ok {
                // Clean up embedding format
                features[k] = strings.Trim(emb, "{}")
            } else {
                features[k] = v
            }
        }
    }
    return
}
```

### Feature Processing for Models

```go
// Process features for ML models (type conversion)
func (u *User) MakeUserFeatures() (features map[string]interface{}) {
    u.mutex.RLock()
    defer u.mutex.RUnlock()
    
    features = make(map[string]interface{})
    for k, v := range u.Properties {
        if k == "type" {
            continue // Skip system fields
        }
        
        // Convert strings to numbers when possible
        if s, ok := v.(float64); ok {
            features[k] = s
            continue
        }
        if str, ok := v.(string); ok {
            if s, err := strconv.ParseFloat(str, 64); err == nil {
                features[k] = s
                continue
            }
        }
        
        features[k] = v
    }
    return
}

// Raw feature copy (no conversion)
func (u *User) MakeUserFeatures2() (features map[string]interface{}) {
    u.mutex.RLock()
    defer u.mutex.RUnlock()
    
    features = make(map[string]interface{}, len(u.Properties))
    for k, v := range u.Properties {
        features[k] = v
    }
    return
}
```

## 🧪 Testing Feature Management

### Property Testing

```go
func TestUserPropertyManagement(t *testing.T) {
    user := NewUser("test_user")
    
    // Test basic property operations
    user.AddProperty("age", 25)
    user.AddProperty("city", "San Francisco")
    
    assert.Equal(t, 25, user.GetProperty("age"))
    assert.Equal(t, "San Francisco", user.StringProperty("city"))
    
    // Test type conversion
    age, err := user.IntProperty("age")
    assert.NoError(t, err)
    assert.Equal(t, 25, age)
    
    // Test batch operations
    properties := map[string]interface{}{
        "gender": "male",
        "score": 85.5,
    }
    user.AddProperties(properties)
    
    assert.Equal(t, "male", user.StringProperty("gender"))
    score, err := user.FloatProperty("score")
    assert.NoError(t, err)
    assert.Equal(t, 85.5, score)
}
```

### Cache Testing

```go
func TestFeatureCaching(t *testing.T) {
    user := NewUser("test_user")
    
    // Test cache operations
    features := map[string]any{
        "ml_score": 0.85,
        "category_pref": "electronics",
    }
    user.AddCacheFeatures("ml_model", features)
    
    // Verify cache contents
    cached := user.GetCacheFeatures("ml_model")
    assert.Equal(t, 0.85, cached["ml_score"])
    assert.Equal(t, "electronics", cached["category_pref"])
    
    // Test loading cached features
    user.LoadCacheFeatures("ml_model")
    assert.Equal(t, 0.85, user.GetProperty("ml_score"))
}
```

### Async Loading Testing

```go
func TestAsyncFeatureLoading(t *testing.T) {
    user := NewUser("test_user")
    
    // Start async operations
    user.IncrementFeatureAsyncLoadCount(2)
    
    go func() {
        defer user.DescFeatureAsyncLoadCount(1)
        time.Sleep(10 * time.Millisecond)
        user.AddCacheFeatures("source1", map[string]any{"feature1": "value1"})
    }()
    
    go func() {
        defer user.DescFeatureAsyncLoadCount(1)
        time.Sleep(20 * time.Millisecond)
        user.AddCacheFeatures("source2", map[string]any{"feature2": "value2"})
    }()
    
    // Wait for completion
    <-user.FeatureAsyncLoadCh()
    
    // Verify async loading completed
    assert.Equal(t, int32(0), user.FeatureAsyncLoadCount())
    
    // Load cached features
    user.LoadCacheFeatures("source1")
    user.LoadCacheFeatures("source2")
    
    assert.Equal(t, "value1", user.StringProperty("feature1"))
    assert.Equal(t, "value2", user.StringProperty("feature2"))
}
```

## 💡 Best Practices

### 1. **Thread Safety**
- Always use provided methods for property access
- Don't access internal maps directly
- Be careful with async operations and shared state

### 2. **Performance Optimization**
- Use caching for expensive feature computations
- Implement async loading for non-critical features
- Batch database operations when possible

### 3. **Memory Management**
- Clean up unused features to prevent memory leaks
- Use appropriate data types for features
- Be mindful of large embedding vectors

### 4. **Error Handling**
- Always handle type conversion errors
- Implement timeouts for external feature services
- Provide fallback values for missing features

### 5. **Feature Organization**
- Use meaningful cache namespace names
- Group related features together
- Document feature schemas and types

## 🔗 Next Steps

- Learn about [Filtering Operations](FILTERING.md) to see how features are used in business rules
- Explore [Data Source Integrations](DATA_SOURCES.md) for specific feature loading implementations
- Review [Testing Patterns](TESTING.md) for comprehensive testing approaches

---

*Return to [Module Guide](MODULE_GUIDE.md) | Continue to [Filtering Operations](FILTERING.md)*