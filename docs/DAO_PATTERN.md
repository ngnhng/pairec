# DAO Pattern & Data Access

Understanding how PaiRec implements the Data Access Object pattern for multi-database support.

## Overview

The module folder extensively uses the DAO (Data Access Object) pattern to provide a clean abstraction layer between business logic and data storage. This design enables PaiRec to support multiple databases and data sources while maintaining a consistent interface.

## 🏗️ DAO Architecture

### Core Design Principles

1. **Interface-First Design**: All data access is defined through interfaces
2. **Multiple Implementations**: Each database gets its own implementation
3. **Factory Pattern**: Configuration-driven DAO creation
4. **Consistent Error Handling**: Standardized error patterns across implementations
5. **Performance Optimization**: Caching and connection pooling built-in

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic                          │
│              (Services, Controllers)                       │
└─────────────────────────────────────────────────────────────┘
                             │
                             │ Uses interfaces only
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                  DAO Interfaces                            │
│  FeatureDao • UserCollaborativeDao • VectorDao • ...       │
└─────────────────────────────────────────────────────────────┘
                             │
                             │ Factory creates implementations
                             ▼
┌─────────────────────────────────────────────────────────────┐
│               DAO Implementations                          │
│  MySQL • Redis • HBase • ClickHouse • Hologres • ...      │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   Data Sources                             │
│    Database Connections • APIs • File Systems              │
└─────────────────────────────────────────────────────────────┘
```

## 📋 DAO Interface Types

The module defines several categories of DAO interfaces, each serving different aspects of the recommendation system:

### 1. **Feature DAOs**
Handle user and item feature loading from various sources.

**Interface**: `FeatureDao`
**File**: `module/feature_dao.go`

```go
type FeatureDao interface {
    FeatureFetch(user *User, items []*Item, context *context.RecommendContext)
}
```

**Implementations**:
- `FeatureMysqlDao` - MySQL database features
- `FeatureRedisDao` - Redis cached features  
- `FeatureHBaseDao` - HBase big data features
- `FeatureClickHouseDao` - ClickHouse analytics features
- `FeatureHologresDao` - Hologres OLAP features
- `FeatureFeatureStoreDao` - Alibaba FeatureStore
- `FeatureTableStoreDao` - Alibaba TableStore
- `FeatureLindormDao` - Alibaba Lindorm
- `FeatureBEDao` - Behavior Engine features

### 2. **Collaborative Filtering DAOs**
Handle user-item interaction data for collaborative filtering algorithms.

**Interface**: `UserCollaborativeDao`
**File**: `module/user_collaborative_dao.go`

```go
type UserCollaborativeDao interface {
    ListItemsByUser(user *User, context *context.RecommendContext) []*Item
    GetTriggers(user *User, context *context.RecommendContext) (itemTriggers map[string]float64)
    GetTriggerInfos(user *User, context *context.RecommendContext) (triggerInfos []*TriggerInfo)
}
```

**Implementations**:
- `UserCollaborativeMysqlDao`
- `UserCollaborativeHologresDao`
- `UserCollaborativeTableStoreDao`
- `UserCollaborativeRedisDao`
- `UserCollaborativeFeatureStoreDao`
- `UserU2I2X2IHologresDao` (User-Item-X-Item pattern)

### 3. **Vector/Embedding DAOs**
Handle similarity search using embeddings and vector databases.

**Interface**: `VectorDao`
**File**: `module/vector_dao.go`

```go
type VectorDao interface {
    VectorRecall(user *User, context *context.RecommendContext) []*Item
    // Additional vector operations...
}
```

**Implementations**:
- `VectorMysqlDao`
- `VectorRedisDao` 
- `VectorHBaseDao`
- `VectorClickHouseDao`
- `VectorHologresDao`
- `VectorBEDao`

### 4. **Custom Recall DAOs**
Handle custom recommendation algorithms and business-specific logic.

**Interface**: `UserCustomRecallDao`

```go
type UserCustomRecallDao interface {
    GetItems(user *User, context *context.RecommendContext) []*Item
}
```

### 5. **Filter DAOs**
Handle business rule filtering and item state management.

**Interfaces**:
- `ItemStateFilterDao` - Item availability filtering
- `ItemCustomFilterDao` - Custom business rule filtering
- `UserItemCustomFilterDao` - User-item specific filtering
- `UserItemExposureDao` - Exposure/impression tracking

## 🏭 Factory Pattern Implementation

### Configuration-Driven Creation

All DAOs are created through factory functions that use configuration objects to determine which implementation to instantiate:

```go
func NewUserCollaborativeDao(config recconf.RecallConfig) UserCollaborativeDao {
    switch config.UserCollaborativeDaoConf.AdapterType {
    case recconf.DaoConf_Adapter_Mysql:
        if config.UserCollaborativeDaoConf.Adapter == "UserCollaborativeMysqlDao" {
            return NewUserCollaborativeMysqlDao(config)
        } else if config.UserCollaborativeDaoConf.Adapter == "UserVideoCollaborativeMysqlDao" {
            return NewUserVideoCollaborativeMysqlDao(config)
        }
    case recconf.DaoConf_Adapter_TableStore:
        return NewUserCollaborativeTableStoreDao(config)
    case recconf.DaoConf_Adapter_Hologres:
        if config.UserCollaborativeDaoConf.Item2XTable != "" && 
           config.UserCollaborativeDaoConf.X2ItemTable != "" {
            return NewUserU2I2X2IHologresDao(config)
        }
        return NewUserCollaborativeHologresDao(config)
    case recconf.DaoConf_Adapter_Redis:
        return NewUserCollaborativeRedisDao(config)
    case recconf.DataSource_Type_FeatureStore:
        return NewUserCollaborativeFeatureStoreDao(config)
    default:
        panic("not found UserCollaborativeDao implement")
    }
}
```

### Configuration Examples

```json
{
  "recall_config": {
    "user_collaborative_dao_conf": {
      "adapter_type": "mysql",
      "adapter": "UserCollaborativeMysqlDao",
      "mysql": {
        "dsn": "user:pass@tcp(localhost:3306)/recommendations",
        "table_name": "user_item_interactions"
      }
    }
  }
}
```

## 🗄️ Database-Specific Implementations

### MySQL Implementation Pattern

**File**: `module/user_collaborative_mysql_dao.go`

```go
type UserCollaborativeMysqlDao struct {
    *UserCollaborativeBaseDao
    db       *sql.DB
    table    string
    // Additional MySQL-specific fields
}

func NewUserCollaborativeMysqlDao(config recconf.RecallConfig) *UserCollaborativeMysqlDao {
    dao := &UserCollaborativeMysqlDao{
        UserCollaborativeBaseDao: NewUserCollaborativeBaseDao(&config),
        table: config.UserCollaborativeDaoConf.MysqlConf.TableName,
    }
    
    // Initialize database connection
    dao.db = mysql.GetDB(config.UserCollaborativeDaoConf.MysqlConf.DSN)
    
    return dao
}

func (d *UserCollaborativeMysqlDao) ListItemsByUser(user *User, context *context.RecommendContext) []*Item {
    // MySQL-specific implementation
    query := fmt.Sprintf("SELECT item_id, score FROM %s WHERE user_id = ?", d.table)
    rows, err := d.db.Query(query, user.Id)
    if err != nil {
        // Handle error
        return nil
    }
    defer rows.Close()
    
    var items []*Item
    for rows.Next() {
        var itemId string
        var score float64
        rows.Scan(&itemId, &score)
        
        item := NewItem(itemId)
        item.Score = score
        item.RetrieveId = d.recallName
        items = append(items, item)
    }
    
    return items
}
```

### Redis Implementation Pattern

**File**: `module/user_collaborative_redis_dao.go`

```go
type UserCollaborativeRedisDao struct {
    *UserCollaborativeBaseDao
    client    redis.Conn
    keyPrefix string
}

func (d *UserCollaborativeRedisDao) ListItemsByUser(user *User, context *context.RecommendContext) []*Item {
    // Redis-specific implementation
    key := fmt.Sprintf("%s:%s", d.keyPrefix, user.Id)
    
    // Use Redis ZREVRANGE for sorted sets
    values, err := redis.Strings(d.client.Do("ZREVRANGE", key, 0, d.size-1, "WITHSCORES"))
    if err != nil {
        return nil
    }
    
    var items []*Item
    for i := 0; i < len(values); i += 2 {
        itemId := values[i]
        score, _ := strconv.ParseFloat(values[i+1], 64)
        
        item := NewItem(itemId)
        item.Score = score
        item.RetrieveId = d.recallName
        items = append(items, item)
    }
    
    return items
}
```

### HBase Implementation Pattern

**File**: `module/user_collaborative_hbase_dao.go`

```go
type UserCollaborativeHBaseDao struct {
    *UserCollaborativeBaseDao
    client    gohbase.Client
    tableName string
}

func (d *UserCollaborativeHBaseDao) ListItemsByUser(user *User, context *context.RecommendContext) []*Item {
    // HBase-specific implementation using column families
    getRequest, err := hrpc.NewGetStr(context.Background(), d.tableName, string(user.Id))
    if err != nil {
        return nil
    }
    
    result, err := d.client.Get(getRequest)
    if err != nil {
        return nil
    }
    
    var items []*Item
    for _, cell := range result.Cells {
        if string(cell.Family) == "cf" { // Column family
            itemId := string(cell.Qualifier)
            score, _ := strconv.ParseFloat(string(cell.Value), 64)
            
            item := NewItem(itemId)
            item.Score = score
            item.RetrieveId = d.recallName
            items = append(items, item)
        }
    }
    
    return items
}
```

## 🔧 Base DAO Pattern

### Common Functionality

Most DAO implementations extend base classes that provide common functionality:

```go
type UserCollaborativeBaseDao struct {
    recallName string
    size       int
    // Common configuration
}

func NewUserCollaborativeBaseDao(config *recconf.RecallConfig) *UserCollaborativeBaseDao {
    return &UserCollaborativeBaseDao{
        recallName: config.Name,
        size:       config.Size,
    }
}
```

### Shared Behavior

Base DAOs handle:
- **Configuration parsing**
- **Common error handling**  
- **Logging and metrics**
- **Result post-processing**
- **Caching mechanisms**

## 🚀 Performance Optimizations

### 1. **Connection Pooling**

```go
// MySQL connection pool
type MysqlConnectionPool struct {
    pools map[string]*sql.DB
    mutex sync.RWMutex
}

func GetDB(dsn string) *sql.DB {
    pool.mutex.RLock()
    if db, exists := pool.pools[dsn]; exists {
        pool.mutex.RUnlock()
        return db
    }
    pool.mutex.RUnlock()
    
    // Create new connection
    pool.mutex.Lock()
    defer pool.mutex.Unlock()
    
    db, err := sql.Open("mysql", dsn)
    if err != nil {
        panic(err)
    }
    
    db.SetMaxOpenConns(100)
    db.SetMaxIdleConns(20)
    pool.pools[dsn] = db
    
    return db
}
```

### 2. **Caching Layer**

```go
type CachedFeatureDao struct {
    underlying FeatureDao
    cache      *cache.Cache
    ttl        time.Duration
}

func (d *CachedFeatureDao) FeatureFetch(user *User, items []*Item, context *context.RecommendContext) {
    cacheKey := fmt.Sprintf("features:%s", user.Id)
    
    if cached, found := d.cache.GetIfPresent(cacheKey); found {
        // Use cached features
        if features, ok := cached.(map[string]interface{}); ok {
            user.AddProperties(features)
            return
        }
    }
    
    // Fetch from underlying DAO
    d.underlying.FeatureFetch(user, items, context)
    
    // Cache the result
    d.cache.Put(cacheKey, user.Properties)
}
```

### 3. **Batch Operations**

```go
func (d *FeatureMysqlDao) FeatureFetch(user *User, items []*Item, context *context.RecommendContext) {
    if len(items) == 0 {
        return
    }
    
    // Batch fetch item features
    itemIds := make([]string, len(items))
    for i, item := range items {
        itemIds[i] = string(item.Id)
    }
    
    query := fmt.Sprintf("SELECT item_id, feature_name, feature_value FROM %s WHERE item_id IN (?%s)",
        d.table, strings.Repeat(",?", len(itemIds)-1))
    
    args := make([]interface{}, len(itemIds))
    for i, id := range itemIds {
        args[i] = id
    }
    
    rows, err := d.db.Query(query, args...)
    // Process batch results...
}
```

## 🔍 Error Handling Patterns

### Consistent Error Handling

```go
func (d *UserCollaborativeMysqlDao) ListItemsByUser(user *User, context *context.RecommendContext) []*Item {
    defer func() {
        if r := recover(); r != nil {
            log.Error(fmt.Sprintf("requestId=%s\tmodule=UserCollaborativeMysqlDao\terror=%v", 
                context.RecommendId, r))
        }
    }()
    
    rows, err := d.db.Query(d.query, user.Id)
    if err != nil {
        log.Error(fmt.Sprintf("requestId=%s\tmodule=UserCollaborativeMysqlDao\tsql=%s\terror=%v",
            context.RecommendId, d.query, err))
        return nil
    }
    
    // Process results...
}
```

### Fallback Mechanisms

```go
type FallbackUserCollaborativeDao struct {
    primary   UserCollaborativeDao
    fallback  UserCollaborativeDao
    timeout   time.Duration
}

func (d *FallbackUserCollaborativeDao) ListItemsByUser(user *User, context *context.RecommendContext) []*Item {
    resultChan := make(chan []*Item, 1)
    
    go func() {
        resultChan <- d.primary.ListItemsByUser(user, context)
    }()
    
    select {
    case result := <-resultChan:
        if result != nil && len(result) > 0 {
            return result
        }
        // Fall back to secondary
        return d.fallback.ListItemsByUser(user, context)
    case <-time.After(d.timeout):
        // Timeout, use fallback
        return d.fallback.ListItemsByUser(user, context)
    }
}
```

## 🧪 Testing DAO Implementations

### Interface Testing

```go
func TestUserCollaborativeDao(t *testing.T) {
    // Test with different implementations
    implementations := []UserCollaborativeDao{
        NewUserCollaborativeMysqlDao(mysqlConfig),
        NewUserCollaborativeRedisDao(redisConfig),
        NewUserCollaborativeHologresDao(hologresConfig),
    }
    
    for _, dao := range implementations {
        t.Run(fmt.Sprintf("%T", dao), func(t *testing.T) {
            testUserCollaborativeBehavior(t, dao)
        })
    }
}

func testUserCollaborativeBehavior(t *testing.T, dao UserCollaborativeDao) {
    user := NewUser("test_user")
    context := &context.RecommendContext{RecommendId: "test_req"}
    
    items := dao.ListItemsByUser(user, context)
    
    // Test common behavior
    assert.NotNil(t, items)
    for _, item := range items {
        assert.NotEmpty(t, item.Id)
        assert.NotEmpty(t, item.RetrieveId)
    }
}
```

### Mock Implementations

```go
type MockUserCollaborativeDao struct {
    items []*Item
    error error
}

func (m *MockUserCollaborativeDao) ListItemsByUser(user *User, context *context.RecommendContext) []*Item {
    if m.error != nil {
        return nil
    }
    return m.items
}

func TestRecommendationService(t *testing.T) {
    mockDao := &MockUserCollaborativeDao{
        items: []*Item{
            NewItem("item1"),
            NewItem("item2"),
        },
    }
    
    service := NewRecommendationService(mockDao)
    result := service.GetRecommendations(user, context)
    
    assert.Len(t, result, 2)
}
```

## 💡 Best Practices

### 1. **Interface Design**
- Keep interfaces focused and cohesive
- Use composition for complex operations
- Design for testability

### 2. **Implementation Patterns**
- Always extend base DAO classes
- Implement consistent error handling
- Use connection pooling for database connections

### 3. **Configuration Management**
- Use factory pattern for DAO creation
- Support runtime configuration changes
- Validate configurations at startup

### 4. **Performance**
- Implement caching where appropriate
- Use batch operations for multiple items
- Consider async loading for non-critical data

### 5. **Testing**
- Test interface contracts, not implementations
- Use mock objects for unit testing
- Include integration tests for database operations

## 🔗 Next Steps

- Explore [Feature Management](FEATURE_MANAGEMENT.md) to see how DAOs are used for feature loading
- Review [Data Source Integrations](DATA_SOURCES.md) for specific database implementation details
- Check [Testing Patterns](TESTING.md) for comprehensive testing strategies

---

*Return to [Module Guide](MODULE_GUIDE.md) | Continue to [Feature Management](FEATURE_MANAGEMENT.md)*