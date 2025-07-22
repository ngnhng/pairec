# Filtering Operations

Comprehensive guide to PaiRec's flexible filtering system for implementing business rules and recommendation logic.

## Overview

PaiRec's filtering system provides a powerful, configurable way to apply business rules to recommendations. The system supports:

- **Multiple filter operators** (equals, contains, greater than, etc.)
- **Domain-specific filtering** (user properties vs item properties)
- **Boolean logic combinations** (AND, OR operations)
- **Cross-domain comparisons** (user property vs item property)
- **Type-safe operations** with automatic conversions

## 🏗️ Filter Architecture

### Core Design

```
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic                           │
│              (Recommendation Rules)                        │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                  Filter Orchestration                      │
│            FilterParam • BoolFilterOp                      │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                 Individual Filter Ops                      │
│   Equal • Contains • Greater • In • IsNull • ...           │
└─────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                   Data Evaluation                          │
│         User Properties • Item Properties                  │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Filter Operation Types

### 1. **Equality Operations**

#### Equal Filter
**File**: `module/filter_op.go` - `EqualFilterOp`

Tests if a property equals a specific value or another property.

```go
// Configuration
{
    "name": "category",
    "domain": "item",
    "operator": "equal", 
    "type": "string",
    "value": "electronics"
}

// Usage: Filter items where category equals "electronics"
```

#### Not Equal Filter
**File**: `module/filter_op.go` - `NotEqualFilterOp`

Tests if a property does not equal a specific value.

```go
// Configuration
{
    "name": "status",
    "domain": "item", 
    "operator": "not_equal",
    "type": "string",
    "value": "discontinued"
}

// Usage: Filter out discontinued items
```

### 2. **Membership Operations**

#### In Filter
**File**: `module/filter_op.go` - `InFilterOp`

Tests if a property value is in a list of allowed values.

```go
// Configuration
{
    "name": "brand",
    "domain": "item",
    "operator": "in",
    "type": "string",
    "value": ["apple", "samsung", "google"]
}

// Usage: Filter items from specific brands
```

#### Not In Filter  
**File**: `module/filter_op.go` - `NotInFilterOp`

Tests if a property value is not in a list of forbidden values.

```go
// Configuration
{
    "name": "region",
    "domain": "user",
    "operator": "not_in", 
    "type": "string",
    "value": ["restricted_region_1", "restricted_region_2"]
}

// Usage: Filter out users from restricted regions
```

### 3. **Collection Operations**

#### Contains Filter
**File**: `module/filter_op.go` - `ContainsFilterOp`

Tests if a collection property contains any values from another collection.

```go
// Configuration
{
    "name": "categories",
    "domain": "item",
    "operator": "contains",
    "type": "[]string", 
    "value": "user.interests"
}

// Usage: Filter items whose categories overlap with user interests
```

#### Not Contains Filter
**File**: `module/filter_op.go` - `NotContainsFilterOp`

Tests if a collection property does not contain any values from another collection.

```go
// Configuration
{
    "name": "restricted_categories",
    "domain": "item",
    "operator": "not_contains",
    "type": "[]string",
    "value": "user.blocked_categories"
}

// Usage: Filter out items in user's blocked categories
```

### 4. **Comparison Operations**

#### Greater Than Filter
**File**: `module/filter_op.go` - `GreaterFilterOp`

Tests if a numeric property is greater than or equal to a value.

```go
// Configuration
{
    "name": "rating",
    "domain": "item",
    "operator": "greater",
    "type": "float",
    "value": 4.0
}

// Usage: Filter items with rating >= 4.0
```

#### Greater Than (Strict) Filter
**File**: `module/filter_op.go` - `GreaterThanFilterOp`

Tests if a numeric property is strictly greater than a value.

```go
// Configuration  
{
    "name": "price",
    "domain": "item",
    "operator": "greaterThan",
    "type": "float",
    "value": "user.budget"
}

// Usage: Filter items more expensive than user budget
```

#### Less Than Filter
**File**: `module/filter_op.go` - `LessFilterOp`

Tests if a numeric property is less than or equal to a value.

```go
// Configuration
{
    "name": "age_required",
    "domain": "item", 
    "operator": "less",
    "type": "int",
    "value": "user.age"
}

// Usage: Filter items appropriate for user's age
```

#### Less Than (Strict) Filter
**File**: `module/filter_op.go` - `LessThanFilterOp`

Tests if a numeric property is strictly less than a value.

### 5. **Null Check Operations**

#### Is Null Filter
**File**: `module/filter_op.go` - `IsNullFilterOp`

Tests if a property is null or missing.

```go
// Configuration
{
    "name": "premium_feature",
    "domain": "item",
    "operator": "is_null"
}

// Usage: Filter items without premium features
```

#### Is Not Null Filter
**File**: `module/filter_op.go` - `IsNotNullFilterOp`

Tests if a property exists and is not null.

```go
// Configuration
{
    "name": "description", 
    "domain": "item",
    "operator": "is_not_null"
}

// Usage: Filter items that have descriptions
```

### 6. **Boolean Logic Operations**

#### Bool Filter
**File**: `module/filter_op.go` - `BoolFilterOp`

Combines multiple filter operations with AND/OR logic.

```go
// Configuration
{
    "operator": "bool",
    "type": "or",
    "configs": [
        {
            "name": "category",
            "operator": "equal",
            "value": "electronics"
        },
        {
            "name": "rating", 
            "operator": "greater",
            "type": "float",
            "value": 4.5
        }
    ]
}

// Usage: Filter items that are electronics OR have high rating
```

## 🔧 Domain-Specific Filtering

### Domain Types

PaiRec supports filtering on different domains:

- **`item`** - Filter based on item properties
- **`user`** - Filter based on user properties  
- **Cross-domain** - Compare user and item properties

### Cross-Domain Comparisons

```go
// Compare user property with item property
{
    "name": "min_age",           // Item property
    "domain": "item",
    "operator": "less",
    "type": "int", 
    "value": "user.age"          // User property
}

// Compare item property with user property
{
    "name": "budget",            // User property
    "domain": "user",
    "operator": "greater",
    "type": "float",
    "value": "item.price"        // Item property
}
```

### Property Reference Syntax

- **Direct value**: `"value": 25`
- **User property**: `"value": "user.age"`
- **Item property**: `"value": "item.price"`
- **Array value**: `"value": ["option1", "option2"]`

## 🎛️ Filter Implementation Details

### Filter Interface

All filter operations implement the core interface:

```go
type FilterOp interface {
    Evaluate(map[string]interface{}) (bool, error)
    OpDomain() string
}

type FilterByDomainOp interface {
    FilterOp
    DomainEvaluate(map[string]any, map[string]any, map[string]any) (bool, error)
}
```

### Example Implementation: EqualFilterOp

```go
type EqualFilterOp struct {
    Name        string      // Property name to check
    Domain      string      // "user" or "item" 
    Type        string      // "string", "int", "float", etc.
    Value       interface{} // Expected value
    DomainValue string      // Cross-domain reference
}

func (p *EqualFilterOp) DomainEvaluate(
    properties map[string]interface{},     // Target domain properties
    userProperties map[string]interface{}, // User properties
    itemProperties map[string]interface{}, // Item properties
) (bool, error) {
    
    // Get the property to test
    left, ok := properties[p.Name]
    if !ok {
        return false, nil
    }

    // Determine comparison value
    var right interface{}
    if p.DomainValue == "" {
        right = p.Value
    } else if strings.HasPrefix(p.DomainValue, "user.") {
        val := p.DomainValue[5:]
        right = userProperties[val]
    } else if strings.HasPrefix(p.DomainValue, "item.") {
        val := p.DomainValue[5:]  
        right = itemProperties[val]
    } else {
        right = p.Value
    }

    // Type-specific comparison
    switch p.Type {
    case "string":
        v1 := utils.ToString(left, "")
        v2 := utils.ToString(right, "")
        return v1 == v2, nil
    case "int":
        v1 := utils.ToInt(left, -1)
        v2 := utils.ToInt(right, -2)
        return v1 == v2, nil
    case "float":
        v1 := utils.ToFloat(left, -1.0)
        v2 := utils.ToFloat(right, -2.0)
        return math.Abs(v1-v2) < 1e-9, nil
    }
    
    return false, nil
}
```

### Factory Pattern for Filter Creation

```go
func NewFilterParamWithConfig(configs []recconf.FilterParamConfig) *FilterParam {
    filterParam := &FilterParam{}
    
    for _, config := range configs {
        var filterOp FilterOp
        
        switch config.Operator {
        case "equal":
            filterOp = NewEqualFilterOp(config)
        case "not_equal":
            filterOp = NewNotEqualFilterOp(config)
        case "in":
            filterOp = NewInFilterOp(config)
        case "not_in":
            filterOp = NewNotInFilterOp(config)
        case "contains":
            filterOp = NewContainsFilterOp(config)
        case "not_contains":
            filterOp = NewNotContainsFilterOp(config)
        case "greater":
            filterOp = NewGreaterFilterOp(config)
        case "greaterThan":
            filterOp = NewGreaterThanFilterOp(config)
        case "less":
            filterOp = NewLessFilterOp(config)
        case "lessThan":
            filterOp = NewLessThanFilterOp(config)
        case "is_null":
            filterOp = NewIsNullFilterOp(config)
        case "is_not_null":
            filterOp = NewIsNotNullFilterOp(config)
        case "bool":
            filterOp = NewBoolFilterOp(config)
        }
        
        if filterOp != nil {
            filterParam.AddFilterOp(filterOp)
        }
    }
    
    return filterParam
}
```

## 📋 FilterParam Orchestration

### FilterParam Structure

```go
type FilterParam struct {
    userFilterOps []FilterOp
    itemFilterOps []FilterOp
}

func (f *FilterParam) EvaluateByDomain(
    userProperties map[string]interface{},
    itemProperties map[string]interface{},
) (bool, error) {
    
    // Evaluate user domain filters
    for _, filterOp := range f.userFilterOps {
        if domainOp, ok := filterOp.(FilterByDomainOp); ok {
            result, err := domainOp.DomainEvaluate(userProperties, userProperties, itemProperties)
            if err != nil || !result {
                return false, err
            }
        }
    }
    
    // Evaluate item domain filters  
    for _, filterOp := range f.itemFilterOps {
        if domainOp, ok := filterOp.(FilterByDomainOp); ok {
            result, err := domainOp.DomainEvaluate(itemProperties, userProperties, itemProperties)
            if err != nil || !result {
                return false, err
            }
        }
    }
    
    return true, nil
}
```

## 🎨 Real-World Usage Examples

### 1. **Content-Based Filtering**

```go
// Filter items matching user preferences
filters := []recconf.FilterParamConfig{
    {
        Name:     "categories",
        Domain:   "item",
        Operator: "contains",
        Type:     "[]string",
        Value:    "user.favorite_categories",
    },
    {
        Name:     "rating",
        Domain:   "item", 
        Operator: "greater",
        Type:     "float",
        Value:    "user.min_rating",
    },
}
```

### 2. **Age-Appropriate Content**

```go
// Filter content appropriate for user's age
filters := []recconf.FilterParamConfig{
    {
        Name:     "min_age_required",
        Domain:   "item",
        Operator: "less",
        Type:     "int",
        Value:    "user.age",
    },
    {
        Name:     "max_age_appropriate", 
        Domain:   "item",
        Operator: "greater",
        Type:     "int",
        Value:    "user.age",
    },
}
```

### 3. **Business Rules Filtering**

```go
// Complex business rule: Premium content for premium users
filters := []recconf.FilterParamConfig{
    {
        Operator: "bool",
        Type:     "or",
        Configs: []recconf.FilterParamConfig{
            {
                Name:     "is_premium",
                Domain:   "item",
                Operator: "equal",
                Type:     "bool",
                Value:    false,
            },
            {
                Name:     "subscription_tier",
                Domain:   "user",
                Operator: "equal", 
                Type:     "string",
                Value:    "premium",
            },
        },
    },
}
```

### 4. **Geographic Filtering**

```go
// Filter content available in user's region
filters := []recconf.FilterParamConfig{
    {
        Name:     "available_regions",
        Domain:   "item",
        Operator: "contains",
        Type:     "[]string", 
        Value:    "user.region",
    },
    {
        Name:     "restricted_regions",
        Domain:   "item",
        Operator: "not_contains",
        Type:     "[]string",
        Value:    "user.region", 
    },
}
```

### 5. **Inventory and Availability**

```go
// Filter available items within price range
filters := []recconf.FilterParamConfig{
    {
        Name:     "in_stock",
        Domain:   "item",
        Operator: "equal",
        Type:     "bool",
        Value:    true,
    },
    {
        Name:     "price",
        Domain:   "item",
        Operator: "less",
        Type:     "float",
        Value:    "user.max_budget",
    },
    {
        Name:     "shipping_cost",
        Domain:   "item", 
        Operator: "less",
        Type:     "float",
        Value:    "user.max_shipping",
    },
}
```

## 🧪 Testing Filter Operations

### Unit Testing Individual Filters

```go
func TestEqualFilterOp(t *testing.T) {
    config := recconf.FilterParamConfig{
        Name:     "category",
        Domain:   "item",
        Operator: "equal",
        Type:     "string",
        Value:    "electronics",
    }
    
    filterOp := NewEqualFilterOp(config)
    
    // Test matching case
    itemProperties := map[string]interface{}{
        "category": "electronics",
    }
    userProperties := map[string]interface{}{}
    
    result, err := filterOp.DomainEvaluate(itemProperties, userProperties, itemProperties)
    assert.NoError(t, err)
    assert.True(t, result)
    
    // Test non-matching case
    itemProperties["category"] = "books"
    result, err = filterOp.DomainEvaluate(itemProperties, userProperties, itemProperties)
    assert.NoError(t, err)
    assert.False(t, result)
}
```

### Integration Testing with FilterParam

```go
func TestFilterParamIntegration(t *testing.T) {
    configs := []recconf.FilterParamConfig{
        {
            Name:     "rating",
            Domain:   "item",
            Operator: "greater",
            Type:     "float",
            Value:    4.0,
        },
        {
            Name:     "price", 
            Domain:   "item",
            Operator: "less",
            Type:     "float",
            Value:    "user.budget",
        },
    }
    
    filterParam := NewFilterParamWithConfig(configs)
    
    userProperties := map[string]interface{}{
        "budget": 100.0,
    }
    
    itemProperties := map[string]interface{}{
        "rating": 4.5,
        "price":  80.0,
    }
    
    result, err := filterParam.EvaluateByDomain(userProperties, itemProperties)
    assert.NoError(t, err)
    assert.True(t, result)
}
```

### Testing Boolean Logic

```go
func TestBoolFilterOp(t *testing.T) {
    config := recconf.FilterParamConfig{
        Operator: "bool",
        Type:     "or",
        Configs: []recconf.FilterParamConfig{
            {
                Name:     "category",
                Operator: "equal",
                Type:     "string",
                Value:    "electronics",
            },
            {
                Name:     "rating",
                Operator: "greater", 
                Type:     "float",
                Value:    4.5,
            },
        },
    }
    
    boolOp := NewBoolFilterOp(config)
    
    // Test first condition true
    properties := map[string]interface{}{
        "category": "electronics",
        "rating":   3.0,
    }
    
    result, err := boolOp.DomainEvaluate(properties, properties, properties)
    assert.NoError(t, err)
    assert.True(t, result) // True because category matches
    
    // Test second condition true
    properties = map[string]interface{}{
        "category": "books",
        "rating":   4.8,
    }
    
    result, err = boolOp.DomainEvaluate(properties, properties, properties)
    assert.NoError(t, err)
    assert.True(t, result) // True because rating is high
}
```

## 💡 Best Practices

### 1. **Filter Design**
- Use specific filter types for better performance
- Combine filters efficiently using boolean operations
- Consider filter order for optimization

### 2. **Configuration Management**
- Use meaningful filter names for debugging
- Document complex boolean logic combinations
- Test filter configurations thoroughly

### 3. **Performance Optimization**
- Place most selective filters first
- Use appropriate data types for comparisons
- Consider caching filter results for repeated evaluations

### 4. **Error Handling**
- Handle missing properties gracefully
- Provide meaningful error messages
- Use fallback values when appropriate

### 5. **Testing Strategy**
- Test each filter type individually
- Test boolean combinations thoroughly
- Include edge cases and error conditions
- Test with real data scenarios

## 🔗 Next Steps

- Explore [Data Source Integrations](DATA_SOURCES.md) to see how filters work with different databases
- Review [Testing Patterns](TESTING.md) for comprehensive testing strategies
- Return to [Module Guide](MODULE_GUIDE.md) for overall architecture context

---

*Return to [Module Guide](MODULE_GUIDE.md) | Continue to [Data Source Integrations](DATA_SOURCES.md)*