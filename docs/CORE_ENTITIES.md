# Core Entities

Understanding the fundamental building blocks of PaiRec's recommendation system.

## Overview

The module folder defines three core entities that form the foundation of the recommendation system:

1. **User** - Represents users with their properties and features
2. **Item** - Represents recommendable items with scores and metadata
3. **Trigger** - Handles strategy selection for different recommendation scenarios

These entities are designed to be thread-safe, extensible, and efficient for high-performance recommendation serving.

## 👤 User Entity

**File**: `module/user.go`

The `User` struct represents a user in the recommendation system with dynamic properties and thread-safe access patterns.

### Core Structure

```go
type User struct {
    Id UID `json:"uid"`
    
    // Thread-safe property storage
    mutex                    sync.RWMutex
    Properties               map[string]interface{}    `json:"properties"`
    
    // Feature caching and async loading
    cacheFeatures            map[string]map[string]any `json:"-"`
    featureAsyncLoadCount    int32
    featureAsyncLoadCh       chan struct{}
    featureAsyncLoadChClosed bool
}
```

### Key Features

#### 1. **Dynamic Properties**
Users can have arbitrary properties (demographics, preferences, behavior features):

```go
user := NewUser("user123")
user.AddProperty("age", 25)
user.AddProperty("gender", "male")
user.AddProperty("city", "San Francisco")

// Type-safe property access
age, err := user.IntProperty("age")
gender := user.StringProperty("gender")
```

#### 2. **Thread-Safe Operations**
All property access is protected by read-write mutexes:

```go
// Safe for concurrent access
go func() {
    user.AddProperty("last_seen", time.Now())
}()

go func() {
    value := user.GetProperty("last_seen")
}()
```

#### 3. **Feature Caching**
Support for caching features from different sources:

```go
// Cache features from a specific source
features := map[string]any{
    "embedding_vector": []float64{0.1, 0.2, 0.3},
    "category_preference": "electronics",
}
user.AddCacheFeatures("ml_features", features)

// Load cached features into main properties
user.LoadCacheFeatures("ml_features")
```

#### 4. **Asynchronous Loading**
Non-blocking feature loading with synchronization:

```go
// Increment async operation counter
user.IncrementFeatureAsyncLoadCount(1)

// Perform async operation
go func() {
    defer user.DescFeatureAsyncLoadCount(1)
    // Load features from external service
    loadFeaturesFromService(user)
}()

// Wait for async operations to complete
<-user.FeatureAsyncLoadCh()
```

### Common Usage Patterns

#### Creating Users

```go
// Basic user creation
user := NewUser("user123")

// User from recommendation context
user := NewUserWithContext(UID("user123"), context)

// Clone existing user
clonedUser := user.Clone()
```

#### Working with Properties

```go
// Single property operations
user.AddProperty("score", 85.5)
score, err := user.FloatProperty("score")
user.DeleteProperty("old_feature")

// Batch operations
properties := map[string]interface{}{
    "segment": "premium",
    "region": "US-West",
}
user.AddProperties(properties)
user.DeleteProperties([]string{"temp1", "temp2"})
```

#### Feature Processing

```go
// Get embedding features (special handling)
embeddings := user.GetEmbeddingFeature()

// Get all features for ML models
allFeatures := user.MakeUserFeatures()   // Type conversion applied
rawFeatures := user.MakeUserFeatures2() // Raw values preserved
```

---

## 📦 Item Entity

**File**: `module/item.go`

The `Item` struct represents recommendable items with scoring capabilities and rich metadata.

### Core Structure

```go
type Item struct {
    Id         ItemId `json:"id"`
    Name       string `json:"name,omitempty"`
    Score      float64
    RetrieveId string    // Which recall algorithm found this item
    ItemType   string
    Embedding  []float64
    
    // Thread-safe property and score storage
    mutex        sync.RWMutex
    Properties   map[string]interface{} `json:"properties"`
    algoScores   map[string]float64     // Scores from different algorithms
    RecallScores map[string]float64     // Scores from recall algorithms
}
```

### Key Features

#### 1. **Multi-Source Scoring**
Items can have scores from multiple algorithms:

```go
item := NewItem("item456")

// Add scores from different algorithms
item.AddAlgoScore("collaborative_filtering", 0.85)
item.AddAlgoScore("content_based", 0.72)
item.AddAlgoScore("deep_learning", 0.91)

// Get specific algorithm score
cfScore := item.GetAlgoScore("collaborative_filtering")

// Get all scores
allScores := item.GetAlgoScores()
```

#### 2. **Rich Metadata**
Dynamic properties with type-safe access:

```go
item.AddProperty("category", "electronics")
item.AddProperty("price", 199.99)
item.AddProperty("brand", "Apple")
item.AddProperty("rating", 4.5)

// Type-safe access
category := item.StringProperty("category")
price, err := item.FloatProperty("price")
rating, err := item.IntProperty("rating")
```

#### 3. **Recall Context**
Track which recall algorithm found the item:

```go
item.RetrieveId = "user_collaborative"
item.Score = 0.85

// This information is automatically added to features
features := item.GetFeatures()
// features["recall_name"] = "user_collaborative"
// features["recall_score"] = 0.85
```

### Common Usage Patterns

#### Creating Items

```go
// Basic item creation
item := NewItem("item456")

// Item with initial properties
properties := map[string]interface{}{
    "title": "iPhone 15",
    "category": "smartphones",
    "price": 999.0,
}
item := NewItemWithProperty("item456", properties)
```

#### Scoring Operations

```go
// Single score operations
item.AddAlgoScore("rank_model", 0.88)
item.IncrAlgoScore("popularity", 0.05) // Increment existing score

// Batch score operations
scores := map[string]float64{
    "model_a": 0.75,
    "model_b": 0.82,
    "model_c": 0.69,
}
item.AddAlgoScores(scores)

// Clone scores for analysis
scoreCopy := item.CloneAlgoScores()
```

#### Feature Processing

```go
// Get features for ranking models
features := item.GetFeatures()

// Get properties without recall info
properties := item.GetProperties()

// Create deep copy
clonedItem := item.DeepClone()
```

#### Expression Evaluation

```go
// Get data for expression evaluation
value, err := item.FloatExprData("current_score") // Returns item.Score
allData := item.ExprData() // All properties + scores
```

---

## 🎯 Trigger Entity

**File**: `module/trigger.go`

The `Trigger` handles strategy selection by creating keys based on user features and configured rules.

### Core Structure

```go
type TriggerItem struct {
    Key          string
    DefaultValue string
    Boundaries   []int    // For numeric binning
}

type Trigger struct {
    triggers []*TriggerItem
}
```

### Key Features

#### 1. **Feature-Based Triggering**
Generate trigger keys from user features:

```go
// Configuration
config := []recconf.TriggerConfig{
    {
        TriggerKey: "age",
        Boundaries: []int{20, 30, 40, 50}, // Age buckets
    },
    {
        TriggerKey: "gender",
        DefaultValue: "unknown",
    },
    {
        TriggerKey: "city",
    },
}

trigger := NewTrigger(config)
```

#### 2. **Numeric Binning**
Automatic binning for continuous features:

```go
features := map[string]interface{}{
    "age": 25,
    "gender": "male",
    "city": "SF",
}

// Generates: "male_20-30_SF"
triggerKey := trigger.GetValue(features)
```

#### 3. **Multi-Value Support**
Handle array/slice features:

```go
features := map[string]interface{}{
    "interests": []string{"sports", "technology", "music"},
}

// Generates: "sports\u001Etechnology\u001Emusic"
triggerKey := trigger.GetValue(features)
```

### Usage Examples

#### Age-Based Triggering

```go
config := []recconf.TriggerConfig{
    {
        TriggerKey: "age",
        Boundaries: []int{18, 25, 35, 50},
    },
}

trigger := NewTrigger(config)

// Different age inputs
trigger.GetValue(map[string]interface{}{"age": 15}) // "<=18"
trigger.GetValue(map[string]interface{}{"age": 22}) // "18-25"
trigger.GetValue(map[string]interface{}{"age": 60}) // ">50"
```

#### Multi-Dimensional Triggering

```go
config := []recconf.TriggerConfig{
    {TriggerKey: "gender"},
    {TriggerKey: "age", Boundaries: []int{30}},
    {TriggerKey: "premium", DefaultValue: "false"},
}

features := map[string]interface{}{
    "gender": "female",
    "age": 28,
    "premium": true,
}

// Generates: "female_<=30_true"
key := trigger.GetValue(features)
```

## 🔄 Entity Interactions

### User-Item Interactions

```go
// User provides context for item scoring
user := NewUser("user123")
user.AddProperty("age", 25)
user.AddProperty("interests", []string{"tech", "sports"})

item := NewItem("item456")
item.AddProperty("category", "tech")

// Items can be scored based on user context
if contains(user.GetProperty("interests"), item.StringProperty("category")) {
    item.AddAlgoScore("interest_match", 1.0)
}
```

### Trigger-Based Strategy Selection

```go
// Use triggers to select recommendation strategy
trigger := NewTrigger(triggerConfig)
strategyKey := trigger.GetValue(user.MakeUserFeatures())

// Different strategies based on trigger key
switch {
case strings.Contains(strategyKey, "premium"):
    // Use premium recommendation algorithm
case strings.Contains(strategyKey, "young"):
    // Use algorithm optimized for younger users
default:
    // Use default algorithm
}
```

## 🧪 Testing Core Entities

The module includes comprehensive tests demonstrating usage patterns:

### User Tests
- Property management (`TestUserProperties`)
- Thread safety (`TestUserConcurrency`)
- Feature caching (`TestUserCacheFeatures`)
- Async loading (`TestUserAsyncLoad`)

### Item Tests
- Scoring operations (`TestItemScoring`)
- Property management (`TestItemProperties`)
- Deep cloning (`TestItemClone`)

### Trigger Tests
- Basic triggering (`TestTrigger`)
- Multi-value features (`TestMultiTrigger`)
- Boundary conditions (`TestTriggerBoundaries`)

## 💡 Best Practices

### 1. **Thread Safety**
- Always use the provided methods for property access
- Don't access internal maps directly
- Be aware of the async loading synchronization

### 2. **Memory Management**
- Use `Clone()` methods when sharing entities between goroutines
- Clean up properties that are no longer needed
- Be mindful of large embedding vectors

### 3. **Type Safety**
- Use type-specific property getters (`IntProperty`, `FloatProperty`, etc.)
- Handle errors from type conversion operations
- Validate property types before storage

### 4. **Performance**
- Cache frequently accessed properties
- Use batch operations when possible
- Consider async loading for expensive feature computations

## 🔗 Next Steps

- Learn about [DAO Pattern & Data Access](DAO_PATTERN.md) to see how these entities are persisted
- Explore [Feature Management](FEATURE_MANAGEMENT.md) for advanced feature handling patterns
- Review [Testing Patterns](TESTING.md) to understand how to test code using these entities

---

*Return to [Module Guide](MODULE_GUIDE.md) | Continue to [DAO Pattern](DAO_PATTERN.md)*