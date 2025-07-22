# Testing Patterns

Comprehensive guide to testing patterns and best practices used in PaiRec's module folder.

## Overview

The module folder demonstrates excellent testing practices for recommendation systems, including:

- **Unit testing** for individual components
- **Integration testing** for database interactions
- **Mock-based testing** for external dependencies
- **Property-based testing** for edge cases
- **Concurrent testing** for thread safety
- **Performance testing** for scalability

## 🧪 Testing Architecture

### Test Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    Test Categories                          │
│   Unit • Integration • Property • Performance              │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                   Testing Tools                            │
│     Go Test • Testify • Mocks • Benchmarks                 │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                 Test Utilities                             │
│   Data Builders • Fixtures • Helpers • Assertions         │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                Test Infrastructure                         │
│      CI/CD • Coverage • Test Databases • Containers       │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Test Types and Examples

### 1. **Core Entity Testing**

#### User Entity Tests
**File**: Based on `module/user.go`

```go
func TestUserPropertyManagement(t *testing.T) {
    user := NewUser("test_user_123")
    
    // Test basic property operations
    user.AddProperty("age", 25)
    user.AddProperty("city", "San Francisco")
    user.AddProperty("score", 85.5)
    
    // Test property retrieval
    assert.Equal(t, 25, user.GetProperty("age"))
    assert.Equal(t, "San Francisco", user.StringProperty("city"))
    
    // Test type-safe access
    age, err := user.IntProperty("age")
    assert.NoError(t, err)
    assert.Equal(t, 25, age)
    
    score, err := user.FloatProperty("score")
    assert.NoError(t, err)
    assert.InDelta(t, 85.5, score, 0.01)
    
    // Test missing property
    _, err = user.IntProperty("nonexistent")
    assert.Error(t, err)
    assert.Contains(t, err.Error(), "property key not exist")
}

func TestUserBatchOperations(t *testing.T) {
    user := NewUser("batch_test_user")
    
    // Test batch property addition
    properties := map[string]interface{}{
        "gender":    "male",
        "premium":   true,
        "score":     92.3,
        "interests": []string{"tech", "sports"},
    }
    user.AddProperties(properties)
    
    // Verify all properties were added
    assert.Equal(t, "male", user.StringProperty("gender"))
    assert.Equal(t, true, user.GetProperty("premium"))
    
    // Test batch deletion
    user.DeleteProperties([]string{"gender", "premium"})
    assert.Nil(t, user.GetProperty("gender"))
    assert.Nil(t, user.GetProperty("premium"))
    
    // Verify other properties remain
    score, err := user.FloatProperty("score")
    assert.NoError(t, err)
    assert.InDelta(t, 92.3, score, 0.01)
}

func TestUserConcurrentAccess(t *testing.T) {
    user := NewUser("concurrent_test_user")
    numGoroutines := 100
    numOperations := 50
    
    var wg sync.WaitGroup
    wg.Add(numGoroutines)
    
    // Concurrent write operations
    for i := 0; i < numGoroutines; i++ {
        go func(id int) {
            defer wg.Done()
            for j := 0; j < numOperations; j++ {
                key := fmt.Sprintf("prop_%d_%d", id, j)
                value := fmt.Sprintf("value_%d_%d", id, j)
                user.AddProperty(key, value)
            }
        }(i)
    }
    
    // Concurrent read operations
    for i := 0; i < numGoroutines; i++ {
        go func(id int) {
            defer wg.Done()
            for j := 0; j < numOperations; j++ {
                key := fmt.Sprintf("prop_%d_%d", id, j%10) // Read existing props
                _ = user.StringProperty(key)
            }
        }(i)
    }
    
    wg.Wait()
    
    // Verify no race conditions occurred
    assert.True(t, len(user.Properties) > 0)
}
```

#### Item Entity Tests
**File**: Based on `module/item.go`

```go
func TestItemScoringOperations(t *testing.T) {
    item := NewItem("test_item_456")
    
    // Test single algorithm scoring
    item.AddAlgoScore("collaborative_filtering", 0.85)
    item.AddAlgoScore("content_based", 0.72)
    item.AddAlgoScore("deep_learning", 0.91)
    
    // Verify scores
    assert.InDelta(t, 0.85, item.GetAlgoScore("collaborative_filtering"), 0.01)
    assert.InDelta(t, 0.72, item.GetAlgoScore("content_based"), 0.01)
    assert.InDelta(t, 0.91, item.GetAlgoScore("deep_learning"), 0.01)
    
    // Test score increment (ensemble methods)
    item.IncrAlgoScore("collaborative_filtering", 0.05)
    assert.InDelta(t, 0.90, item.GetAlgoScore("collaborative_filtering"), 0.01)
    
    // Test batch scoring
    scores := map[string]float64{
        "popularity":   0.65,
        "trending":     0.78,
        "personalized": 0.88,
    }
    item.AddAlgoScores(scores)
    
    allScores := item.GetAlgoScores()
    assert.Len(t, allScores, 6) // 3 initial + 3 batch
    assert.Contains(t, allScores, "popularity")
    assert.InDelta(t, 0.65, allScores["popularity"], 0.01)
}

func TestItemFeatureProcessing(t *testing.T) {
    item := NewItem("feature_test_item")
    item.RetrieveId = "collaborative_recall"
    item.Score = 0.75
    
    // Add item properties
    item.AddProperty("category", "electronics")
    item.AddProperty("price", 199.99)
    item.AddProperty("brand", "Apple")
    item.AddProperty("rating", 4.5)
    
    // Test feature extraction
    features := item.GetFeatures()
    
    // Verify recall information is included
    assert.Equal(t, "collaborative_recall", features["recall_name"])
    assert.InDelta(t, 0.75, features["recall_score"].(float64), 0.01)
    assert.InDelta(t, 0.75, features["collaborative_recall"].(float64), 0.01)
    
    // Verify properties are included
    assert.Equal(t, "electronics", features["category"])
    assert.InDelta(t, 199.99, features["price"].(float64), 0.01)
    
    // Test expression data (includes algorithm scores)
    item.AddAlgoScore("rank_model", 0.82)
    exprData := item.ExprData()
    
    assert.Contains(t, exprData, "rank_model")
    assert.InDelta(t, 0.82, exprData["rank_model"].(float64), 0.01)
    assert.Contains(t, exprData, "category")
    assert.Equal(t, "electronics", exprData["category"])
}

func TestItemDeepClone(t *testing.T) {
    original := NewItem("clone_test_item")
    original.Score = 0.85
    original.RetrieveId = "test_recall"
    original.ItemType = "product"
    
    // Add properties and scores
    original.AddProperty("category", "books")
    original.AddProperty("price", 29.99)
    original.AddAlgoScore("model_a", 0.75)
    original.AddAlgoScore("model_b", 0.82)
    
    // Create deep clone
    cloned := original.DeepClone()
    
    // Verify clone independence
    assert.Equal(t, original.Id, cloned.Id)
    assert.Equal(t, original.Score, cloned.Score)
    assert.Equal(t, original.RetrieveId, cloned.RetrieveId)
    
    // Test that modifications don't affect original
    cloned.AddProperty("new_property", "new_value")
    cloned.AddAlgoScore("new_model", 0.90)
    
    assert.Nil(t, original.GetProperty("new_property"))
    assert.Equal(t, 0.0, original.GetAlgoScore("new_model"))
    
    // But cloned item has the new data
    assert.Equal(t, "new_value", cloned.StringProperty("new_property"))
    assert.InDelta(t, 0.90, cloned.GetAlgoScore("new_model"), 0.01)
}
```

### 2. **Filter Operation Testing**

#### Filter Logic Tests
**File**: `module/filter_op_test.go`

```go
func TestEqualFilterOp(t *testing.T) {
    testCases := []struct {
        name           string
        config         recconf.FilterParamConfig
        userProperties map[string]interface{}
        itemProperties map[string]interface{}
        expected       bool
    }{
        {
            name: "Simple string equality",
            config: recconf.FilterParamConfig{
                Name:     "category",
                Domain:   "item",
                Operator: "equal",
                Type:     "string",
                Value:    "electronics",
            },
            itemProperties: map[string]interface{}{
                "category": "electronics",
            },
            expected: true,
        },
        {
            name: "Cross-domain comparison",
            config: recconf.FilterParamConfig{
                Name:     "min_age",
                Domain:   "item",
                Operator: "equal",
                Type:     "int",
                Value:    "user.age",
            },
            itemProperties: map[string]interface{}{
                "min_age": 25,
            },
            userProperties: map[string]interface{}{
                "age": 25,
            },
            expected: true,
        },
        {
            name: "Type conversion test",
            config: recconf.FilterParamConfig{
                Name:     "score",
                Domain:   "item", 
                Operator: "equal",
                Type:     "int",
                Value:    42,
            },
            itemProperties: map[string]interface{}{
                "score": "42", // String that should convert to int
            },
            expected: true,
        },
    }
    
    for _, tc := range testCases {
        t.Run(tc.name, func(t *testing.T) {
            filterOp := NewEqualFilterOp(tc.config)
            result, err := filterOp.DomainEvaluate(
                tc.itemProperties,
                tc.userProperties,
                tc.itemProperties,
            )
            
            assert.NoError(t, err)
            assert.Equal(t, tc.expected, result)
        })
    }
}

func TestBooleanFilterCombinations(t *testing.T) {
    // Test complex boolean logic: (category = "electronics" OR rating > 4.0) AND price < budget
    config := recconf.FilterParamConfig{
        Operator: "bool",
        Type:     "and",
        Configs: []recconf.FilterParamConfig{
            {
                Operator: "bool",
                Type:     "or",
                Configs: []recconf.FilterParamConfig{
                    {
                        Name:     "category",
                        Domain:   "item",
                        Operator: "equal",
                        Type:     "string",
                        Value:    "electronics",
                    },
                    {
                        Name:     "rating",
                        Domain:   "item",
                        Operator: "greater",
                        Type:     "float",
                        Value:    4.0,
                    },
                },
            },
            {
                Name:     "price",
                Domain:   "item",
                Operator: "less",
                Type:     "float",
                Value:    "user.budget",
            },
        },
    }
    
    boolOp := NewBoolFilterOp(config)
    
    testCases := []struct {
        name           string
        userProperties map[string]interface{}
        itemProperties map[string]interface{}
        expected       bool
    }{
        {
            name: "Electronics item under budget",
            userProperties: map[string]interface{}{"budget": 100.0},
            itemProperties: map[string]interface{}{
                "category": "electronics",
                "rating":   3.5,
                "price":    80.0,
            },
            expected: true, // category matches AND price < budget
        },
        {
            name: "High-rated non-electronics under budget",
            userProperties: map[string]interface{}{"budget": 100.0},
            itemProperties: map[string]interface{}{
                "category": "books",
                "rating":   4.5,
                "price":    25.0,
            },
            expected: true, // rating > 4.0 AND price < budget
        },
        {
            name: "Electronics over budget",
            userProperties: map[string]interface{}{"budget": 100.0},
            itemProperties: map[string]interface{}{
                "category": "electronics",
                "rating":   3.5,
                "price":    150.0,
            },
            expected: false, // category matches BUT price >= budget
        },
    }
    
    for _, tc := range testCases {
        t.Run(tc.name, func(t *testing.T) {
            result, err := boolOp.DomainEvaluate(
                tc.itemProperties,
                tc.userProperties,
                tc.itemProperties,
            )
            
            assert.NoError(t, err)
            assert.Equal(t, tc.expected, result)
        })
    }
}
```

### 3. **Async Feature Loading Tests**

```go
func TestAsyncFeatureLoading(t *testing.T) {
    user := NewUser("async_test_user")
    
    // Test async operation counter
    assert.Equal(t, int32(0), user.FeatureAsyncLoadCount())
    
    // Start multiple async operations
    user.IncrementFeatureAsyncLoadCount(3)
    assert.Equal(t, int32(3), user.FeatureAsyncLoadCount())
    
    // Simulate async operations completing
    var wg sync.WaitGroup
    wg.Add(3)
    
    // Async operation 1: ML features
    go func() {
        defer wg.Done()
        defer user.DescFeatureAsyncLoadCount(1)
        
        time.Sleep(10 * time.Millisecond) // Simulate work
        features := map[string]any{
            "ml_score":          0.85,
            "predicted_category": "electronics",
        }
        user.AddCacheFeatures("ml_model", features)
    }()
    
    // Async operation 2: Behavior features
    go func() {
        defer wg.Done()
        defer user.DescFeatureAsyncLoadCount(1)
        
        time.Sleep(15 * time.Millisecond) // Simulate work
        features := map[string]any{
            "session_duration": 1200,
            "pages_viewed":     15,
        }
        user.AddCacheFeatures("behavior", features)
    }()
    
    // Async operation 3: Profile features
    go func() {
        defer wg.Done()
        defer user.DescFeatureAsyncLoadCount(1)
        
        time.Sleep(5 * time.Millisecond) // Simulate work
        features := map[string]any{
            "age":    25,
            "gender": "male",
        }
        user.AddCacheFeatures("profile", features)
    }()
    
    // Wait for completion signal
    select {
    case <-user.FeatureAsyncLoadCh():
        // All operations completed
        break
    case <-time.After(100 * time.Millisecond):
        t.Fatal("Async operations did not complete within timeout")
    }
    
    wg.Wait() // Ensure all goroutines finished
    
    // Verify counter reached zero
    assert.Equal(t, int32(0), user.FeatureAsyncLoadCount())
    
    // Load and verify cached features
    user.LoadCacheFeatures("ml_model")
    user.LoadCacheFeatures("behavior")
    user.LoadCacheFeatures("profile")
    
    assert.Equal(t, 0.85, user.GetProperty("ml_score"))
    assert.Equal(t, "electronics", user.StringProperty("predicted_category"))
    assert.Equal(t, 1200, user.GetProperty("session_duration"))
    assert.Equal(t, 25, user.GetProperty("age"))
}

func TestAsyncLoadingTimeout(t *testing.T) {
    user := NewUser("timeout_test_user")
    user.IncrementFeatureAsyncLoadCount(1)
    
    // Start long-running operation
    go func() {
        time.Sleep(200 * time.Millisecond) // Longer than timeout
        user.DescFeatureAsyncLoadCount(1)
    }()
    
    // Test timeout behavior
    ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
    defer cancel()
    
    select {
    case <-user.FeatureAsyncLoadCh():
        t.Fatal("Should not have completed within timeout")
    case <-ctx.Done():
        // Expected timeout
        assert.True(t, user.FeatureAsyncLoadCount() > 0)
    }
}
```

### 4. **Trigger System Testing**

**File**: `module/trigger_test.go`

```go
func TestTriggerBasicFunctionality(t *testing.T) {
    config := []recconf.TriggerConfig{
        {
            TriggerKey: "gender",
        },
        {
            TriggerKey: "age",
            Boundaries: []int{20, 30, 40, 50},
        },
        {
            TriggerKey: "city",
        },
    }
    
    trigger := NewTrigger(config)
    
    testCases := []struct {
        name     string
        features map[string]interface{}
        expected string
    }{
        {
            name: "Young male from SF",
            features: map[string]interface{}{
                "gender": "male",
                "age":    25,
                "city":   "san_francisco",
            },
            expected: "male_20-30_san_francisco",
        },
        {
            name: "Older female, missing city",
            features: map[string]interface{}{
                "gender": "female", 
                "age":    45,
            },
            expected: "female_40-50_NULL",
        },
        {
            name: "Very young user",
            features: map[string]interface{}{
                "gender": "male",
                "age":    18,
                "city":   "nyc",
            },
            expected: "male_<=20_nyc",
        },
        {
            name: "Very old user", 
            features: map[string]interface{}{
                "gender": "female",
                "age":    65,
                "city":   "chicago",
            },
            expected: "female_>50_chicago",
        },
    }
    
    for _, tc := range testCases {
        t.Run(tc.name, func(t *testing.T) {
            result := trigger.GetValue(tc.features)
            assert.Equal(t, tc.expected, result)
        })
    }
}

func TestTriggerMultiValueFeatures(t *testing.T) {
    config := []recconf.TriggerConfig{
        {
            TriggerKey: "interests",
        },
    }
    
    trigger := NewTrigger(config)
    
    testCases := []struct {
        name     string
        features map[string]interface{}
        expected string
    }{
        {
            name: "String slice interests",
            features: map[string]interface{}{
                "interests": []string{"tech", "sports", "music"},
            },
            expected: strings.Join([]string{"tech", "sports", "music"}, TIRRGER_SPLIT),
        },
        {
            name: "Interface slice interests",
            features: map[string]interface{}{
                "interests": []any{"gaming", "travel", "food"},
            },
            expected: strings.Join([]string{"gaming", "travel", "food"}, TIRRGER_SPLIT),
        },
        {
            name: "Int slice",
            features: map[string]interface{}{
                "interests": []int{1, 2, 3},
            },
            expected: strings.Join([]string{"1", "2", "3"}, TIRRGER_SPLIT),
        },
    }
    
    for _, tc := range testCases {
        t.Run(tc.name, func(t *testing.T) {
            result := trigger.GetValue(tc.features)
            assert.Equal(t, tc.expected, result)
        })
    }
}
```

### 5. **DAO Testing Patterns**

#### Mock DAO Implementation

```go
// Mock interface for testing
type MockUserCollaborativeDao struct {
    items         []*Item
    triggers      map[string]float64
    triggerInfos  []*TriggerInfo
    error         error
    callCount     int
    lastUser      *User
    lastContext   *context.RecommendContext
}

func NewMockUserCollaborativeDao() *MockUserCollaborativeDao {
    return &MockUserCollaborativeDao{
        items:        []*Item{},
        triggers:     make(map[string]float64),
        triggerInfos: []*TriggerInfo{},
    }
}

func (m *MockUserCollaborativeDao) ListItemsByUser(user *User, context *context.RecommendContext) []*Item {
    m.callCount++
    m.lastUser = user
    m.lastContext = context
    
    if m.error != nil {
        return nil
    }
    
    return m.items
}

func (m *MockUserCollaborativeDao) GetTriggers(user *User, context *context.RecommendContext) map[string]float64 {
    return m.triggers
}

func (m *MockUserCollaborativeDao) GetTriggerInfos(user *User, context *context.RecommendContext) []*TriggerInfo {
    return m.triggerInfos
}

// Test using mock
func TestRecommendationServiceWithMock(t *testing.T) {
    mockDao := NewMockUserCollaborativeDao()
    
    // Set up mock data
    mockDao.items = []*Item{
        NewItem("item1"),
        NewItem("item2"),
        NewItem("item3"),
    }
    mockDao.items[0].Score = 0.9
    mockDao.items[1].Score = 0.8
    mockDao.items[2].Score = 0.7
    
    // Create service with mock
    service := NewRecommendationService(mockDao)
    user := NewUser("test_user")
    context := &context.RecommendContext{RecommendId: "test_request"}
    
    // Execute
    items := service.GetCollaborativeItems(user, context)
    
    // Verify results
    assert.Len(t, items, 3)
    assert.Equal(t, "item1", string(items[0].Id))
    assert.InDelta(t, 0.9, items[0].Score, 0.01)
    
    // Verify mock was called correctly
    assert.Equal(t, 1, mockDao.callCount)
    assert.Equal(t, user, mockDao.lastUser)
    assert.Equal(t, context, mockDao.lastContext)
}
```

#### Database Integration Testing

```go
func TestFeatureDaoIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test in short mode")
    }
    
    // Set up test database
    db, err := setupTestDatabase()
    require.NoError(t, err)
    defer teardownTestDatabase(db)
    
    // Insert test data
    insertTestData(t, db)
    
    // Create DAO with test configuration
    config := recconf.FeatureDaoConfig{
        AdapterType:      recconf.DaoConf_Adapter_Mysql,
        MysqlName:        "test_db",
        MysqlTableName:   "test_features",
        FeatureStore:     Feature_Store_User,
    }
    
    dao := NewFeatureMysqlDao(config)
    require.NotNil(t, dao)
    
    // Test feature fetching
    user := NewUser("test_user_123")
    context := &context.RecommendContext{RecommendId: "integration_test"}
    
    dao.FeatureFetch(user, []*Item{}, context)
    
    // Verify features were loaded
    assert.Equal(t, "male", user.StringProperty("gender"))
    assert.Equal(t, 25, user.GetProperty("age"))
    assert.Equal(t, "premium", user.StringProperty("tier"))
}

func setupTestDatabase() (*sql.DB, error) {
    // Create in-memory SQLite database for testing
    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        return nil, err
    }
    
    // Create test schema
    schema := `
        CREATE TABLE test_features (
            user_id TEXT,
            feature_name TEXT,
            feature_value TEXT,
            PRIMARY KEY (user_id, feature_name)
        );
    `
    
    _, err = db.Exec(schema)
    return db, err
}

func insertTestData(t *testing.T, db *sql.DB) {
    testData := []struct {
        userID       string
        featureName  string
        featureValue string
    }{
        {"test_user_123", "gender", "male"},
        {"test_user_123", "age", "25"},
        {"test_user_123", "tier", "premium"},
        {"test_user_456", "gender", "female"},
        {"test_user_456", "age", "30"},
        {"test_user_456", "tier", "basic"},
    }
    
    for _, data := range testData {
        _, err := db.Exec(
            "INSERT INTO test_features (user_id, feature_name, feature_value) VALUES (?, ?, ?)",
            data.userID, data.featureName, data.featureValue,
        )
        require.NoError(t, err)
    }
}
```

### 6. **Performance and Benchmark Testing**

```go
func BenchmarkUserPropertyAccess(b *testing.B) {
    user := NewUser("bench_user")
    
    // Pre-populate with properties
    for i := 0; i < 1000; i++ {
        key := fmt.Sprintf("prop_%d", i)
        value := fmt.Sprintf("value_%d", i)
        user.AddProperty(key, value)
    }
    
    b.ResetTimer()
    
    b.Run("StringProperty", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            key := fmt.Sprintf("prop_%d", i%1000)
            _ = user.StringProperty(key)
        }
    })
    
    b.Run("GetProperty", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            key := fmt.Sprintf("prop_%d", i%1000)
            _ = user.GetProperty(key)
        }
    })
    
    b.Run("AddProperty", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            key := fmt.Sprintf("new_prop_%d", i)
            value := fmt.Sprintf("new_value_%d", i)
            user.AddProperty(key, value)
        }
    })
}

func BenchmarkFilterOperations(b *testing.B) {
    // Set up test data
    userProps := map[string]interface{}{
        "age":    25,
        "budget": 100.0,
        "region": "US",
    }
    
    itemProps := map[string]interface{}{
        "price":    80.0,
        "category": "electronics",
        "rating":   4.5,
    }
    
    configs := []recconf.FilterParamConfig{
        {
            Name:     "price",
            Domain:   "item",
            Operator: "less",
            Type:     "float",
            Value:    "user.budget",
        },
        {
            Name:     "rating",
            Domain:   "item", 
            Operator: "greater",
            Type:     "float",
            Value:    4.0,
        },
    }
    
    filterParam := NewFilterParamWithConfig(configs)
    
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        _, _ = filterParam.EvaluateByDomain(userProps, itemProps)
    }
}

func BenchmarkAsyncFeatureLoading(b *testing.B) {
    b.Run("Sequential", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            user := NewUser(fmt.Sprintf("user_%d", i))
            
            // Simulate sequential feature loading
            features1 := map[string]any{"f1": "v1", "f2": "v2"}
            features2 := map[string]any{"f3": "v3", "f4": "v4"}
            
            user.AddCacheFeatures("source1", features1)
            user.AddCacheFeatures("source2", features2)
            user.LoadCacheFeatures("source1")
            user.LoadCacheFeatures("source2")
        }
    })
    
    b.Run("Async", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            user := NewUser(fmt.Sprintf("user_%d", i))
            user.IncrementFeatureAsyncLoadCount(2)
            
            // Simulate async feature loading
            go func() {
                defer user.DescFeatureAsyncLoadCount(1)
                features := map[string]any{"f1": "v1", "f2": "v2"}
                user.AddCacheFeatures("source1", features)
            }()
            
            go func() {
                defer user.DescFeatureAsyncLoadCount(1)
                features := map[string]any{"f3": "v3", "f4": "v4"}
                user.AddCacheFeatures("source2", features)
            }()
            
            <-user.FeatureAsyncLoadCh()
        }
    })
}
```

### 7. **Property-Based Testing**

```go
func TestUserPropertyFuzz(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping fuzz test in short mode")
    }
    
    f := func(keys []string, values []interface{}) bool {
        if len(keys) != len(values) || len(keys) == 0 {
            return true // Skip invalid inputs
        }
        
        user := NewUser("fuzz_user")
        
        // Add all properties
        for i, key := range keys {
            if key != "" { // Skip empty keys
                user.AddProperty(key, values[i])
            }
        }
        
        // Verify all non-empty keys can be retrieved
        for i, key := range keys {
            if key != "" {
                retrieved := user.GetProperty(key)
                if retrieved != values[i] {
                    return false
                }
            }
        }
        
        return true
    }
    
    // Run property-based test
    quick.Check(f, &quick.Config{MaxCount: 1000})
}

func TestFilterOperationProperties(t *testing.T) {
    // Property: Equal filter should be reflexive (x == x is always true)
    reflexive := func(value interface{}) bool {
        if value == nil {
            return true
        }
        
        config := recconf.FilterParamConfig{
            Name:     "test_prop",
            Domain:   "item",
            Operator: "equal",
            Type:     "string",
            Value:    value,
        }
        
        filterOp := NewEqualFilterOp(config)
        properties := map[string]interface{}{
            "test_prop": value,
        }
        
        result, err := filterOp.DomainEvaluate(properties, properties, properties)
        return err == nil && result == true
    }
    
    quick.Check(reflexive, nil)
    
    // Property: Not equal filter should be symmetric
    symmetric := func(value1, value2 interface{}) bool {
        if value1 == nil || value2 == nil || value1 == value2 {
            return true
        }
        
        config := recconf.FilterParamConfig{
            Name:     "test_prop",
            Domain:   "item", 
            Operator: "not_equal",
            Type:     "string",
            Value:    value2,
        }
        
        filterOp := NewNotEqualFilterOp(config)
        properties := map[string]interface{}{
            "test_prop": value1,
        }
        
        result, err := filterOp.DomainEvaluate(properties, properties, properties)
        return err == nil && result == true
    }
    
    quick.Check(symmetric, nil)
}
```

## 🎯 Test Organization and Best Practices

### Test File Structure

```
module/
├── user.go
├── user_test.go              # Unit tests for user entity
├── item.go  
├── item_test.go              # Unit tests for item entity
├── filter_op.go
├── filter_op_test.go         # Unit tests for filter operations
├── trigger.go
├── trigger_test.go           # Unit tests for trigger system
├── *_dao.go                  # DAO implementations
├── *_dao_test.go            # DAO unit tests
└── integration_test.go       # Cross-component integration tests
```

### Test Utilities and Helpers

```go
// Test data builders
func NewTestUser(id string) *User {
    user := NewUser(id)
    user.AddProperty("age", 25)
    user.AddProperty("gender", "male")
    user.AddProperty("region", "US")
    return user
}

func NewTestItem(id string) *Item {
    item := NewItem(id)
    item.AddProperty("category", "electronics")
    item.AddProperty("price", 99.99)
    item.AddProperty("rating", 4.2)
    item.Score = 0.8
    item.RetrieveId = "test_recall"
    return item
}

// Custom assertions
func AssertUserHasProperty(t *testing.T, user *User, key string, expected interface{}) {
    t.Helper()
    actual := user.GetProperty(key)
    assert.Equal(t, expected, actual, "User should have property %s with value %v", key, expected)
}

func AssertItemScore(t *testing.T, item *Item, algorithm string, expected float64) {
    t.Helper()
    actual := item.GetAlgoScore(algorithm)
    assert.InDelta(t, expected, actual, 0.01, "Item should have %s score of %f", algorithm, expected)
}

// Test fixtures
var StandardUserProperties = map[string]interface{}{
    "age":      25,
    "gender":   "male", 
    "region":   "US",
    "premium":  false,
    "interests": []string{"tech", "sports"},
}

var StandardItemProperties = map[string]interface{}{
    "category": "electronics",
    "price":    99.99,
    "rating":   4.2,
    "brand":    "Apple",
    "in_stock": true,
}
```

### Continuous Integration Configuration

```yaml
# .github/workflows/test.yml
name: Test Module

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: test
          MYSQL_DATABASE: test_db
        ports:
          - 3306:3306
          
      redis:
        image: redis:alpine
        ports:
          - 6379:6379
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Go
      uses: actions/setup-go@v2
      with:
        go-version: 1.19
    
    - name: Install dependencies
      run: go mod download
    
    - name: Run tests
      run: |
        go test -v -race -coverprofile=coverage.out ./module/...
        
    - name: Run benchmarks
      run: go test -bench=. -benchmem ./module/...
      
    - name: Upload coverage
      uses: codecov/codecov-action@v1
      with:
        file: ./coverage.out
```

## 💡 Testing Best Practices

### 1. **Test Organization**
- One test file per source file (`user.go` → `user_test.go`)
- Group related tests using subtests (`t.Run()`)
- Use descriptive test names that explain the scenario

### 2. **Test Data Management**
- Use builders and factories for test data creation
- Create reusable fixtures for common scenarios
- Avoid hardcoding values; use constants and variables

### 3. **Mocking and Isolation**
- Mock external dependencies (databases, APIs)
- Test interfaces, not implementations
- Use dependency injection for testable code

### 4. **Performance Testing**
- Include benchmarks for performance-critical code
- Test concurrent access patterns
- Measure memory allocations with `-benchmem`

### 5. **Integration Testing**
- Test with real databases when possible
- Use containerized dependencies for consistency
- Include end-to-end scenarios

### 6. **Error Handling**
- Test both success and failure paths
- Verify error messages and types
- Test edge cases and boundary conditions

## 🔗 Next Steps

- Return to [Module Guide](MODULE_GUIDE.md) for overall architecture context
- Review [Core Entities](CORE_ENTITIES.md) for component-specific testing patterns
- Explore [Feature Management](FEATURE_MANAGEMENT.md) for async testing examples

---

*Return to [Module Guide](MODULE_GUIDE.md) | Complete documentation series*