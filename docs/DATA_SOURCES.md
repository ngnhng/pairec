# Data Source Integrations

Comprehensive guide to PaiRec's multi-database support and data source integration patterns.

## Overview

PaiRec supports **10+ different data sources** through a consistent DAO interface pattern. This enables organizations to use their existing data infrastructure while benefiting from PaiRec's recommendation capabilities. Each data source is optimized for specific use cases and access patterns.

## 🗄️ Supported Data Sources

### 1. **MySQL** - Relational Database
**Use Cases**: Traditional OLTP, user profiles, item catalogs, transaction data
**Files**: `*_mysql_dao.go`

### 2. **Redis** - In-Memory Cache  
**Use Cases**: Real-time features, session data, hot item lists, caching layer
**Files**: `*_redis_dao.go`

### 3. **HBase** - NoSQL Big Data
**Use Cases**: Large-scale user behavior, historical interactions, analytics data
**Files**: `*_hbase_thrift_dao.go`

### 4. **ClickHouse** - OLAP Analytics
**Use Cases**: Real-time analytics, aggregated metrics, time-series data
**Files**: `*_clickhouse_dao.go`

### 5. **Hologres** - Cloud OLAP
**Use Cases**: Alibaba Cloud analytics, real-time OLAP, large-scale feature serving
**Files**: `*_hologres_dao.go`

### 6. **TableStore** - NoSQL Document Store
**Use Cases**: Alibaba Cloud NoSQL, flexible schema, high-performance reads
**Files**: `*_tablestore_dao.go`

### 7. **FeatureStore** - ML Feature Platform
**Use Cases**: Alibaba FeatureStore, ML feature serving, model training data
**Files**: `*_featurestore_dao.go`

### 8. **Lindorm** - Multi-Model Database
**Use Cases**: Alibaba Lindorm, time-series + NoSQL, IoT data
**Files**: `*_lindorm_dao.go`

### 9. **Behavior Engine (BE)** - Real-Time Analytics
**Use Cases**: Real-time user behavior, event streaming, online features
**Files**: `*_be_dao.go`

### 10. **Vector Databases** - Similarity Search
**Use Cases**: Embedding storage, similarity search, neural recommendation
**Implementation**: Integrated through various backends

## 🏗️ Data Source Architecture

### Layered Integration Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                   Application Layer                        │
│         Recommendation Services & Controllers              │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                  Unified DAO Interfaces                    │
│   FeatureDao • UserCollaborativeDao • VectorDao • ...      │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│              Database-Specific Implementations             │
│    MySQL • Redis • HBase • ClickHouse • Hologres • ...     │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                 Connection Management                      │
│      Connection Pools • Client Libraries • SDKs           │
└─────────────────────────────────────────────────────────────┘
```

## 📊 Data Source Comparison

| Data Source | Type | Use Case | Performance | Scalability | Features |
|-------------|------|----------|-------------|-------------|----------|
| **MySQL** | RDBMS | OLTP, Structured Data | High | Medium | ACID, Joins, Complex Queries |
| **Redis** | Cache | Real-time, Sessions | Very High | Medium | In-Memory, Pub/Sub, Data Structures |
| **HBase** | NoSQL | Big Data, Time-Series | Medium | Very High | Column-Family, Horizontal Scale |
| **ClickHouse** | OLAP | Analytics, Aggregations | High | High | Columnar, Real-time Analytics |
| **Hologres** | Cloud OLAP | Cloud Analytics | High | Very High | Real-time OLAP, Alibaba Cloud |
| **TableStore** | NoSQL | Document Store | High | High | Flexible Schema, Alibaba Cloud |
| **FeatureStore** | ML Platform | Feature Serving | High | High | ML Optimized, Alibaba Platform |
| **Lindorm** | Multi-Model | Time-Series + NoSQL | High | Very High | Multi-Model, Alibaba Cloud |
| **BE** | Real-Time | Streaming Analytics | Very High | High | Event-Driven, Real-Time |

## 🔧 Implementation Patterns

### 1. **MySQL Implementation Pattern**

**File**: `module/feature_mysql_dao.go`

```go
type FeatureMysqlDao struct {
    *FeatureBaseDao
    db           *sql.DB
    table        string
    userFields   string
    itemFields   string
    mu           sync.RWMutex
    userStmt     *sql.Stmt
    itemStmtMap  map[int]*sql.Stmt
}

func NewFeatureMysqlDao(config recconf.FeatureDaoConfig) *FeatureMysqlDao {
    dao := &FeatureMysqlDao{
        FeatureBaseDao: NewFeatureBaseDao(&config),
        table:          config.MysqlTableName,
        itemStmtMap:    make(map[int]*sql.Stmt),
    }
    
    // Initialize database connection with pooling
    mysql, err := mysqldb.GetMysql(config.MysqlName)
    if err != nil {
        log.Error(fmt.Sprintf("MySQL connection error: %v", err))
        return nil
    }
    dao.db = mysql.DB
    
    // Pre-compile statements for performance
    dao.initStatements()
    
    return dao
}

func (d *FeatureMysqlDao) userFeatureFetch(user *User, context *context.RecommendContext) {
    // Use prepared statement for performance
    rows, err := d.userStmt.Query(string(user.Id))
    if err != nil {
        log.Error(fmt.Sprintf("MySQL query error: %v", err))
        return
    }
    defer rows.Close()
    
    features := make(map[string]interface{})
    for rows.Next() {
        var featureName, featureValue string
        if err := rows.Scan(&featureName, &featureValue); err != nil {
            continue
        }
        features[featureName] = featureValue
    }
    
    user.AddProperties(features)
}
```

### 2. **Redis Implementation Pattern**

**File**: `module/feature_redis_dao.go`

```go
type FeatureRedisDao struct {
    *FeatureBaseDao
    client      redis.Conn
    keyPrefix   string
    hashFields  []string
    pipeline    bool
}

func NewFeatureRedisDao(config recconf.FeatureDaoConfig) *FeatureRedisDao {
    dao := &FeatureRedisDao{
        FeatureBaseDao: NewFeatureBaseDao(&config),
        keyPrefix:      config.RedisKeyPrefix,
        pipeline:       config.RedisPipeline,
    }
    
    // Initialize Redis connection pool
    dao.client = redis.NewPool(func() (redis.Conn, error) {
        return redis.Dial("tcp", config.RedisAddr,
            redis.DialPassword(config.RedisPassword),
            redis.DialDatabase(config.RedisDB))
    }, config.RedisMaxIdle).Get()
    
    return dao
}

func (d *FeatureRedisDao) userFeatureFetch(user *User, context *context.RecommendContext) {
    key := fmt.Sprintf("%s:%s", d.keyPrefix, user.Id)
    
    if d.pipeline {
        // Use Redis pipeline for batch operations
        d.client.Send("MULTI")
        for _, field := range d.hashFields {
            d.client.Send("HGET", key, field)
        }
        replies, err := redis.Values(d.client.Do("EXEC"))
        if err != nil {
            return
        }
        
        features := make(map[string]interface{})
        for i, reply := range replies {
            if reply != nil {
                features[d.hashFields[i]] = string(reply.([]byte))
            }
        }
        user.AddProperties(features)
    } else {
        // Single hash get all operation
        values, err := redis.StringMap(d.client.Do("HGETALL", key))
        if err != nil {
            return
        }
        
        features := make(map[string]interface{})
        for k, v := range values {
            features[k] = v
        }
        user.AddProperties(features)
    }
}
```

### 3. **HBase Implementation Pattern**

**File**: `module/feature_hbase_thrift_dao.go`

```go
type FeatureHBaseThriftDao struct {
    *FeatureBaseDao
    client       *hbase.HbaseClient
    tableName    string
    columnFamily string
    transport    thrift.TTransport
}

func NewFeatureHBaseThriftDao(config recconf.FeatureDaoConfig) *FeatureHBaseThriftDao {
    dao := &FeatureHBaseThriftDao{
        FeatureBaseDao: NewFeatureBaseDao(&config),
        tableName:      config.HBaseTableName,
        columnFamily:   config.HBaseColumnFamily,
    }
    
    // Initialize HBase Thrift client
    transportFactory := thrift.NewTFramedTransportFactory(thrift.NewTTransportFactory())
    protocolFactory := thrift.NewTBinaryProtocolFactoryDefault()
    
    transport, err := thrift.NewTSocket(config.HBaseHost + ":" + config.HBasePort)
    if err != nil {
        log.Error(fmt.Sprintf("HBase connection error: %v", err))
        return nil
    }
    
    dao.transport = transportFactory.GetTransport(transport)
    dao.client = hbase.NewHbaseClientFactory(dao.transport, protocolFactory)
    dao.transport.Open()
    
    return dao
}

func (d *FeatureHBaseThriftDao) userFeatureFetch(user *User, context *context.RecommendContext) {
    rowKey := string(user.Id)
    
    // HBase row get operation
    rows, err := d.client.GetRow(d.tableName, rowKey, nil)
    if err != nil || len(rows) == 0 {
        return
    }
    
    features := make(map[string]interface{})
    for _, trowResult := range rows {
        for _, cell := range trowResult.Columns {
            // Parse column qualifier as feature name
            qualifier := strings.TrimPrefix(string(cell.Column), d.columnFamily+":")
            features[qualifier] = string(cell.Value)
        }
    }
    
    user.AddProperties(features)
}
```

### 4. **ClickHouse Implementation Pattern**

**File**: `module/feature_clickhouse_dao.go`

```go
type FeatureClickHouseDao struct {
    *FeatureBaseDao
    db          *sql.DB
    database    string
    table       string
    selectSQL   string
    whereSQL    string
}

func NewFeatureClickHouseDao(config recconf.FeatureDaoConfig) *FeatureClickHouseDao {
    dao := &FeatureClickHouseDao{
        FeatureBaseDao: NewFeatureBaseDao(&config),
        database:       config.ClickHouseDatabase,
        table:          config.ClickHouseTable,
    }
    
    // ClickHouse connection with specific driver
    dsn := fmt.Sprintf("tcp://%s:%d?database=%s&username=%s&password=%s",
        config.ClickHouseHost, config.ClickHousePort,
        config.ClickHouseDatabase, config.ClickHouseUser, config.ClickHousePassword)
    
    db, err := sql.Open("clickhouse", dsn)
    if err != nil {
        log.Error(fmt.Sprintf("ClickHouse connection error: %v", err))
        return nil
    }
    dao.db = db
    
    // Build optimized query for ClickHouse
    dao.buildQueries()
    
    return dao
}

func (d *FeatureClickHouseDao) buildQueries() {
    // ClickHouse-optimized query construction
    d.selectSQL = fmt.Sprintf(`
        SELECT feature_name, feature_value 
        FROM %s.%s 
        WHERE user_id = ? 
        AND event_date >= today() - 30
        ORDER BY event_time DESC
        LIMIT 1000
    `, d.database, d.table)
}

func (d *FeatureClickHouseDao) userFeatureFetch(user *User, context *context.RecommendContext) {
    rows, err := d.db.Query(d.selectSQL, string(user.Id))
    if err != nil {
        log.Error(fmt.Sprintf("ClickHouse query error: %v", err))
        return
    }
    defer rows.Close()
    
    features := make(map[string]interface{})
    for rows.Next() {
        var featureName, featureValue string
        if err := rows.Scan(&featureName, &featureValue); err != nil {
            continue
        }
        
        // ClickHouse often returns aggregated data
        if existing, exists := features[featureName]; exists {
            // Combine multiple values (e.g., sum, average)
            features[featureName] = d.combineValues(existing, featureValue)
        } else {
            features[featureName] = featureValue
        }
    }
    
    user.AddProperties(features)
}
```

### 5. **Hologres Implementation Pattern**

**File**: `module/feature_hologres_dao.go`

```go
type FeatureHologresDao struct {
    *FeatureBaseDao
    db                      *sql.DB
    table                   string
    userFeatureKeyName      string
    itemFeatureKeyName      string
    timestampFeatureKeyName string
    mu                      sync.RWMutex
    userStmt                *sql.Stmt
    itemStmtMap             map[int]*sql.Stmt
}

func NewFeatureHologresDao(config recconf.FeatureDaoConfig) *FeatureHologresDao {
    dao := &FeatureHologresDao{
        FeatureBaseDao:     NewFeatureBaseDao(&config),
        table:              config.HologresTableName,
        userFeatureKeyName: config.UserFeatureKeyName,
        itemStmtMap:        make(map[int]*sql.Stmt),
    }
    
    // Hologres (PostgreSQL-compatible) connection
    holo, err := holo.GetHolo(config.HologresName)
    if err != nil {
        log.Error(fmt.Sprintf("Hologres connection error: %v", err))
        return nil
    }
    dao.db = holo.DB
    
    // Pre-compile statements for Hologres optimization
    dao.initStatements()
    
    return dao
}

func (d *FeatureHologresDao) userFeatureFetch(user *User, context *context.RecommendContext) {
    // Hologres supports complex analytical queries
    query := fmt.Sprintf(`
        SELECT feature_name, feature_value, feature_timestamp
        FROM %s 
        WHERE %s = $1 
        AND feature_timestamp >= NOW() - INTERVAL '7 days'
        ORDER BY feature_timestamp DESC
    `, d.table, d.userFeatureKeyName)
    
    rows, err := d.db.Query(query, string(user.Id))
    if err != nil {
        log.Error(fmt.Sprintf("Hologres query error: %v", err))
        return
    }
    defer rows.Close()
    
    features := make(map[string]interface{})
    latestTimestamps := make(map[string]time.Time)
    
    for rows.Next() {
        var featureName, featureValue string
        var featureTimestamp time.Time
        
        if err := rows.Scan(&featureName, &featureValue, &featureTimestamp); err != nil {
            continue
        }
        
        // Keep only the most recent value for each feature
        if lastTime, exists := latestTimestamps[featureName]; !exists || featureTimestamp.After(lastTime) {
            features[featureName] = featureValue
            latestTimestamps[featureName] = featureTimestamp
        }
    }
    
    user.AddProperties(features)
}
```

## 🚀 Performance Optimizations

### Connection Pooling

```go
// MySQL connection pool configuration
type MySQLPool struct {
    pools map[string]*sql.DB
    mutex sync.RWMutex
}

func GetMySQLConnection(dsn string) *sql.DB {
    pool.mutex.RLock()
    if db, exists := pool.pools[dsn]; exists {
        pool.mutex.RUnlock()
        return db
    }
    pool.mutex.RUnlock()
    
    pool.mutex.Lock()
    defer pool.mutex.Unlock()
    
    db, err := sql.Open("mysql", dsn)
    if err != nil {
        return nil
    }
    
    // Optimize connection pool settings
    db.SetMaxOpenConns(100)
    db.SetMaxIdleConns(20)
    db.SetConnMaxLifetime(time.Hour)
    
    pool.pools[dsn] = db
    return db
}
```

### Prepared Statements

```go
// Pre-compile frequently used statements
func (d *FeatureMysqlDao) initStatements() {
    var err error
    
    // User feature query
    userQuery := fmt.Sprintf("SELECT feature_name, feature_value FROM %s WHERE user_id = ?", d.table)
    d.userStmt, err = d.db.Prepare(userQuery)
    if err != nil {
        log.Error(fmt.Sprintf("Failed to prepare user statement: %v", err))
    }
    
    // Item feature queries for different batch sizes
    for _, size := range []int{1, 10, 50, 100} {
        placeholders := strings.Repeat("?,", size-1) + "?"
        itemQuery := fmt.Sprintf("SELECT item_id, feature_name, feature_value FROM %s WHERE item_id IN (%s)", d.table, placeholders)
        d.itemStmtMap[size], err = d.db.Prepare(itemQuery)
        if err != nil {
            log.Error(fmt.Sprintf("Failed to prepare item statement for size %d: %v", size, err))
        }
    }
}
```

### Batch Operations

```go
// Redis pipeline for batch operations
func (d *FeatureRedisDao) batchItemFeatureFetch(items []*Item, context *context.RecommendContext) {
    if len(items) == 0 {
        return
    }
    
    // Use Redis pipeline for multiple operations
    d.client.Send("MULTI")
    for _, item := range items {
        key := fmt.Sprintf("%s:item:%s", d.keyPrefix, item.Id)
        d.client.Send("HGETALL", key)
    }
    
    replies, err := redis.Values(d.client.Do("EXEC"))
    if err != nil {
        log.Error(fmt.Sprintf("Redis pipeline error: %v", err))
        return
    }
    
    // Process results
    for i, reply := range replies {
        if reply != nil {
            if values, ok := reply.([]interface{}); ok {
                features := d.parseRedisHash(values)
                items[i].AddProperties(features)
            }
        }
    }
}
```

### Caching Layer

```go
// Multi-level caching strategy
type CachedFeatureDao struct {
    underlying   FeatureDao
    localCache   *cache.Cache        // Local in-memory cache
    redisCache   redis.Conn          // Distributed cache
    cacheTTL     time.Duration
}

func (d *CachedFeatureDao) FeatureFetch(user *User, items []*Item, context *context.RecommendContext) {
    // Check local cache first
    cacheKey := fmt.Sprintf("features:%s", user.Id)
    if cached, found := d.localCache.GetIfPresent(cacheKey); found {
        user.AddProperties(cached.(map[string]interface{}))
        return
    }
    
    // Check Redis cache
    redisKey := fmt.Sprintf("user_features:%s", user.Id)
    if cached, err := redis.StringMap(d.redisCache.Do("HGETALL", redisKey)); err == nil && len(cached) > 0 {
        features := make(map[string]interface{})
        for k, v := range cached {
            features[k] = v
        }
        user.AddProperties(features)
        
        // Update local cache
        d.localCache.Put(cacheKey, features)
        return
    }
    
    // Fetch from underlying data source
    d.underlying.FeatureFetch(user, items, context)
    
    // Cache the results
    features := user.MakeUserFeatures2()
    d.localCache.Put(cacheKey, features)
    
    // Cache in Redis
    for k, v := range features {
        d.redisCache.Do("HSET", redisKey, k, v)
    }
    d.redisCache.Do("EXPIRE", redisKey, int(d.cacheTTL.Seconds()))
}
```

## 🎯 Data Source Selection Guide

### Use Case Matrix

| Scenario | Recommended Data Source | Rationale |
|----------|------------------------|-----------|
| **User Profiles** | MySQL + Redis Cache | ACID properties for consistency, Redis for speed |
| **Real-time Features** | Redis + BE | In-memory performance, real-time updates |
| **Historical Behavior** | HBase + ClickHouse | Scale for big data, analytics capabilities |
| **ML Feature Serving** | FeatureStore + Hologres | ML-optimized, real-time OLAP |
| **Product Catalog** | MySQL + TableStore | Structured data, flexible schema for variants |
| **Embeddings/Vectors** | Specialized Vector DB + Redis | Optimized similarity search, fast retrieval |
| **Analytics Data** | ClickHouse + Hologres | Columnar storage, real-time analytics |
| **Session Data** | Redis + BE | In-memory speed, session lifecycle |

### Configuration Examples

#### Multi-Source Configuration

```json
{
  "feature_dags": [
    {
      "name": "user_profile_features",
      "adapter_type": "mysql",
      "mysql_name": "user_db",
      "table_name": "user_profiles",
      "feature_store": "user"
    },
    {
      "name": "realtime_behavior", 
      "adapter_type": "redis",
      "redis_addr": "redis-cluster:6379",
      "key_prefix": "user_behavior",
      "feature_store": "user"
    },
    {
      "name": "item_features",
      "adapter_type": "hologres",
      "hologres_name": "analytics_db", 
      "table_name": "item_features",
      "feature_store": "item"
    }
  ]
}
```

#### Fallback Configuration

```json
{
  "feature_dao": {
    "primary": {
      "adapter_type": "featurestore",
      "timeout": "100ms"
    },
    "fallback": {
      "adapter_type": "mysql",
      "timeout": "500ms"
    }
  }
}
```

## 🧪 Testing Multi-Database Support

### Database Mock Pattern

```go
// Interface for testable database operations
type DatabaseClient interface {
    Query(query string, args ...interface{}) (*sql.Rows, error)
    Exec(query string, args ...interface{}) (sql.Result, error)
}

// Mock implementation for testing
type MockDatabaseClient struct {
    queries map[string][]map[string]interface{}
    errors  map[string]error
}

func (m *MockDatabaseClient) Query(query string, args ...interface{}) (*sql.Rows, error) {
    if err, exists := m.errors[query]; exists {
        return nil, err
    }
    
    // Return mocked rows based on query
    if results, exists := m.queries[query]; exists {
        return createMockRows(results), nil
    }
    
    return createMockRows([]map[string]interface{}{}), nil
}
```

### Integration Testing

```go
func TestMultiDatabaseIntegration(t *testing.T) {
    // Test with different database configurations
    configs := []struct {
        name     string
        adapter  string
        expected int
    }{
        {"MySQL", "mysql", 5},
        {"Redis", "redis", 3},
        {"HBase", "hbase", 10},
    }
    
    for _, config := range configs {
        t.Run(config.name, func(t *testing.T) {
            dao := createFeatureDao(config.adapter)
            user := NewUser("test_user")
            context := &context.RecommendContext{}
            
            dao.FeatureFetch(user, []*Item{}, context)
            
            assert.GreaterOrEqual(t, len(user.Properties), config.expected)
        })
    }
}
```

## 💡 Best Practices

### 1. **Data Source Selection**
- Choose based on access patterns and performance requirements
- Use appropriate data sources for specific use cases
- Consider data consistency requirements

### 2. **Performance Optimization**
- Implement connection pooling for all data sources
- Use prepared statements for frequently executed queries
- Implement caching at multiple levels

### 3. **Error Handling**
- Implement graceful fallbacks between data sources
- Use circuit breakers for external dependencies
- Log errors with sufficient context for debugging

### 4. **Configuration Management**
- Use environment-specific configurations
- Implement configuration validation at startup
- Support dynamic configuration updates where possible

### 5. **Monitoring and Observability**
- Monitor connection pool utilization
- Track query performance across data sources
- Implement health checks for all dependencies

## 🔗 Next Steps

- Review [Testing Patterns](TESTING.md) for comprehensive testing strategies across data sources
- Explore [Feature Management](FEATURE_MANAGEMENT.md) to understand how data sources integrate with feature loading
- Return to [Module Guide](MODULE_GUIDE.md) for overall architecture context

---

*Return to [Module Guide](MODULE_GUIDE.md) | Continue to [Testing Patterns](TESTING.md)*