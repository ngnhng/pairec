# Response Handling

This guide covers how PaiRec algorithms produce, process, and consume responses. Understanding response handling is crucial for integrating algorithms effectively and building complex recommendation pipelines.

## Table of Contents
- [Response Interface Design](#response-interface-design)
- [Standard Response Types](#standard-response-types)
- [Custom Response Processing](#custom-response-processing)
- [Response Transformation](#response-transformation)
- [Error Handling](#error-handling)
- [Multi-Algorithm Response Combination](#multi-algorithm-response-combination)
- [Performance Considerations](#performance-considerations)
- [Best Practices](#best-practices)

## Response Interface Design

### The AlgoResponse Interface

All PaiRec algorithms return data that implements the `AlgoResponse` interface, providing a consistent way to extract scores and metadata:

```go
type AlgoResponse interface {
    GetScore() float64                    // Primary relevance score
    GetScoreMap() map[string]float64     // Multiple named scores
    GetModuleType() bool                 // Algorithm type metadata
}
```

**📍 File Reference**: [`algorithm/response/response.go:3-7`](../../algorithm/response/response.go#L3-L7)

### Extended Response Interfaces

For algorithms that return classification results:

```go
type AlgoMultiClassifyResponse interface {
    GetClassifyMap() map[string][]float64  // class_name -> probabilities
}
```

### Response Function Type

Custom response processors use this function signature:

```go
type ResponseFunc func(interface{}) ([]AlgoResponse, error)
```

### Design Principles

#### 1. **Uniform Interface**
All algorithms return the same interface, enabling polymorphic processing:

```go
// Same processing code works for any algorithm type
func processAlgorithmResults(results []AlgoResponse) []ScoredItem {
    items := make([]ScoredItem, len(results))
    for i, result := range results {
        items[i] = ScoredItem{
            Score:    result.GetScore(),
            Scores:   result.GetScoreMap(),  // May be nil
            Metadata: result.GetModuleType(),
        }
    }
    return items
}
```

#### 2. **Flexible Scoring**
Support both single scores and multi-dimensional scoring:

```go
// Single score for ranking
score := response.GetScore()  // 0.85

// Multiple scores for different criteria
scoreMap := response.GetScoreMap()
if scoreMap != nil {
    relevance := scoreMap["relevance"]     // 0.85
    popularity := scoreMap["popularity"]   // 0.72
    freshness := scoreMap["freshness"]     // 0.91
}
```

#### 3. **Extensible Design**
Easy to add new response types without breaking existing code:

```go
// Check for extended interfaces
if classifier, ok := response.(AlgoMultiClassifyResponse); ok {
    categories := classifier.GetClassifyMap()
    // Process classification results
}
```

## Standard Response Types

### LOOKUP Response

The simplest response type, containing only a score:

```go
type LookupResponse struct {
    score float64
}

func (r *LookupResponse) GetScore() float64 {
    return r.score
}

func (r *LookupResponse) GetScoreMap() map[string]float64 {
    return nil  // LOOKUP only provides single scores
}

func (r *LookupResponse) GetModuleType() bool {
    return false
}
```

**📍 File Reference**: [`algorithm/lookup.go:12-26`](../../algorithm/lookup.go#L12-L26)

#### Usage Example:
```go
// LOOKUP returns simple scored responses
result, _ := algorithm.Run("score-lookup", featureData)
if responses, ok := result.([]response.AlgoResponse); ok {
    for i, resp := range responses {
        fmt.Printf("Item %d: score=%.3f\n", i, resp.GetScore())
    }
}
// Output:
// Item 0: score=0.850
// Item 1: score=0.720
```

### EAS Response

EAS algorithms can return complex, multi-dimensional responses:

```go
type EasResponse struct {
    Score       float64                 // Primary score
    ScoreMap    map[string]float64     // Multiple model outputs
    Features    map[string]interface{} // Feature importance/embeddings
    ModelInfo   map[string]string      // Model metadata
}

func (r *EasResponse) GetScore() float64 {
    return r.Score
}

func (r *EasResponse) GetScoreMap() map[string]float64 {
    return r.ScoreMap
}

func (r *EasResponse) GetModuleType() bool {
    return true  // Complex ML algorithm
}
```

#### Usage Example:
```go
// EAS returns rich, multi-dimensional responses
result, _ := algorithm.Run("deep-ranker", features)
if responses, ok := result.([]response.AlgoResponse); ok {
    for i, resp := range responses {
        score := resp.GetScore()
        scoreMap := resp.GetScoreMap()
        
        fmt.Printf("Item %d: primary=%.3f", i, score)
        if scoreMap != nil {
            fmt.Printf(", ctr=%.3f, cvr=%.3f", 
                scoreMap["ctr_score"], scoreMap["cvr_score"])
        }
        fmt.Println()
    }
}
// Output:
// Item 0: primary=0.850, ctr=0.120, cvr=0.045
// Item 1: primary=0.720, ctr=0.095, cvr=0.038
```

### Vector Search Response

Vector similarity algorithms typically return distance-based scores:

```go
type VectorResponse struct {
    similarity float64
    distance   float64
    itemID     string
}

func (r *VectorResponse) GetScore() float64 {
    return r.similarity  // Converted to similarity score
}

func (r *VectorResponse) GetScoreMap() map[string]float64 {
    return map[string]float64{
        "similarity": r.similarity,
        "distance":   r.distance,
    }
}
```

### Classification Response

For algorithms that perform multi-class classification:

```go
type ClassificationResponse struct {
    topClass    string
    score       float64
    classProbas map[string][]float64
}

func (r *ClassificationResponse) GetScore() float64 {
    return r.score  // Confidence of top prediction
}

func (r *ClassificationResponse) GetClassifyMap() map[string][]float64 {
    return r.classProbas
}

// Example usage
if classifier, ok := response.(AlgoMultiClassifyResponse); ok {
    classes := classifier.GetClassifyMap()
    categories := classes["category"]     // [0.6, 0.3, 0.1] for 3 categories
    sentiments := classes["sentiment"]    // [0.1, 0.2, 0.7] for negative/neutral/positive
}
```

## Custom Response Processing

### Response Function Registration

Algorithms can register custom response processing functions to transform raw model outputs into structured responses:

```go
// Register custom response processor
algorithm.RegistRequestDataFunc("enhanced-eas", func(name string, data interface{}) interface{} {
    // This processes the input; for output processing, use response functions
    return data
})

// Response functions are configured per algorithm
type CustomResponseProcessor struct{}

func (c *CustomResponseProcessor) ProcessEasResponse(rawResponse interface{}) ([]response.AlgoResponse, error) {
    // Convert raw EAS JSON to structured responses
    if easData, ok := rawResponse.(map[string]interface{}); ok {
        predictions := easData["predictions"].([]interface{})
        responses := make([]response.AlgoResponse, len(predictions))
        
        for i, pred := range predictions {
            predMap := pred.(map[string]interface{})
            
            responses[i] = &EasResponse{
                Score: predMap["score"].(float64),
                ScoreMap: map[string]float64{
                    "ctr_score": predMap["ctr"].(float64),
                    "cvr_score": predMap["cvr"].(float64),
                },
                Features: predMap["features"].(map[string]interface{}),
            }
        }
        
        return responses, nil
    }
    return nil, fmt.Errorf("invalid EAS response format")
}
```

### Algorithm-Specific Response Patterns

#### TensorFlow Serving Response Processing

```go
func processTensorFlowResponse(tfResponse interface{}) ([]response.AlgoResponse, error) {
    // TF Serving returns: {"predictions": [[score1], [score2], ...]}
    if tfData, ok := tfResponse.(map[string]interface{}); ok {
        predictions := tfData["predictions"].([]interface{})
        responses := make([]response.AlgoResponse, len(predictions))
        
        for i, pred := range predictions {
            predArray := pred.([]interface{})
            score := predArray[0].(float64)  // First output is primary score
            
            responses[i] = &TensorFlowResponse{
                Score: score,
                RawOutputs: predArray,
            }
        }
        
        return responses, nil
    }
    return nil, fmt.Errorf("invalid TensorFlow response")
}
```

#### FAISS Response Processing

```go
func processFaissResponse(faissResponse interface{}) ([]response.AlgoResponse, error) {
    // FAISS returns: {"results": [{"item_id": "...", "score": ...}, ...]}
    if faissData, ok := faissResponse.(*pb.VectorReply); ok {
        responses := make([]response.AlgoResponse, len(faissData.Results))
        
        for i, result := range faissData.Results {
            responses[i] = &VectorResponse{
                similarity: result.Score,
                distance:   1.0 - result.Score,  // Convert similarity to distance
                itemID:     result.ItemId,
            }
        }
        
        return responses, nil
    }
    return nil, fmt.Errorf("invalid FAISS response")
}
```

#### Milvus Response Processing

```go
func processMilvusResponse(milvusResponse interface{}) ([]response.AlgoResponse, error) {
    // Milvus SDK returns native SearchResult objects
    if searchResults, ok := milvusResponse.([]client.SearchResult); ok {
        var allResponses []response.AlgoResponse
        
        for _, result := range searchResults {
            for i := 0; i < result.ResultCount; i++ {
                itemID := result.IDs.GetAsString(i)
                score := result.Scores[i]
                
                allResponses = append(allResponses, &VectorResponse{
                    similarity: score,
                    itemID:     itemID,
                })
            }
        }
        
        return allResponses, nil
    }
    return nil, fmt.Errorf("invalid Milvus response")
}
```

## Response Transformation

### Score Normalization

Different algorithms may return scores in different ranges. Normalize them for consistent comparison:

```go
type NormalizedResponse struct {
    originalScore float64
    normalizedScore float64
    algorithm string
}

func (r *NormalizedResponse) GetScore() float64 {
    return r.normalizedScore
}

func normalizeScores(responses []response.AlgoResponse, method string) []response.AlgoResponse {
    scores := make([]float64, len(responses))
    for i, resp := range responses {
        scores[i] = resp.GetScore()
    }
    
    var normalized []float64
    switch method {
    case "minmax":
        normalized = minMaxNormalize(scores)
    case "zscore":
        normalized = zScoreNormalize(scores)
    case "sigmoid":
        normalized = sigmoidNormalize(scores)
    }
    
    result := make([]response.AlgoResponse, len(responses))
    for i, resp := range responses {
        result[i] = &NormalizedResponse{
            originalScore:   resp.GetScore(),
            normalizedScore: normalized[i],
            algorithm:      getAlgorithmType(resp),
        }
    }
    
    return result
}

func minMaxNormalize(scores []float64) []float64 {
    min, max := findMinMax(scores)
    normalized := make([]float64, len(scores))
    
    for i, score := range scores {
        if max == min {
            normalized[i] = 0.5  // All scores identical
        } else {
            normalized[i] = (score - min) / (max - min)
        }
    }
    
    return normalized
}
```

### Response Filtering

Filter responses based on score thresholds or other criteria:

```go
func filterResponses(responses []response.AlgoResponse, minScore float64) []response.AlgoResponse {
    var filtered []response.AlgoResponse
    
    for _, resp := range responses {
        if resp.GetScore() >= minScore {
            filtered = append(filtered, resp)
        }
    }
    
    return filtered
}

func filterByScoreMap(responses []response.AlgoResponse, filters map[string]float64) []response.AlgoResponse {
    var filtered []response.AlgoResponse
    
    for _, resp := range responses {
        scoreMap := resp.GetScoreMap()
        if scoreMap == nil {
            continue
        }
        
        passesFilter := true
        for field, minValue := range filters {
            if score, ok := scoreMap[field]; !ok || score < minValue {
                passesFilter = false
                break
            }
        }
        
        if passesFilter {
            filtered = append(filtered, resp)
        }
    }
    
    return filtered
}

// Usage
responses := getAlgorithmResponses()
highQuality := filterByScoreMap(responses, map[string]float64{
    "relevance": 0.7,
    "quality":   0.6,
    "freshness": 0.5,
})
```

### Response Enrichment

Add additional metadata or computed fields to responses:

```go
type EnrichedResponse struct {
    original response.AlgoResponse
    metadata map[string]interface{}
}

func (r *EnrichedResponse) GetScore() float64 {
    return r.original.GetScore()
}

func (r *EnrichedResponse) GetScoreMap() map[string]float64 {
    baseMap := r.original.GetScoreMap()
    if baseMap == nil {
        baseMap = make(map[string]float64)
    }
    
    // Add computed scores
    if confidence, ok := r.metadata["confidence"].(float64); ok {
        baseMap["confidence"] = confidence
    }
    
    return baseMap
}

func enrichResponses(responses []response.AlgoResponse, itemIDs []string) []response.AlgoResponse {
    enriched := make([]response.AlgoResponse, len(responses))
    
    for i, resp := range responses {
        metadata := map[string]interface{}{
            "item_id":      itemIDs[i],
            "timestamp":    time.Now().Unix(),
            "algorithm":    getAlgorithmType(resp),
            "confidence":   calculateConfidence(resp),
        }
        
        enriched[i] = &EnrichedResponse{
            original: resp,
            metadata: metadata,
        }
    }
    
    return enriched
}
```

## Error Handling

### Graceful Response Processing

Handle cases where algorithms return errors or malformed responses:

```go
func safeProcessResponse(algorithmName string, inputData interface{}) ([]response.AlgoResponse, error) {
    // Execute algorithm with error handling
    result, err := algorithm.Run(algorithmName, inputData)
    if err != nil {
        return nil, fmt.Errorf("algorithm %s failed: %v", algorithmName, err)
    }
    
    // Type assertion with error checking
    responses, ok := result.([]response.AlgoResponse)
    if !ok {
        // Handle raw responses that need conversion
        if converted, convertErr := convertToAlgoResponse(result); convertErr == nil {
            return converted, nil
        }
        return nil, fmt.Errorf("algorithm %s returned invalid response type: %T", algorithmName, result)
    }
    
    // Validate response contents
    return validateResponses(responses, algorithmName)
}

func validateResponses(responses []response.AlgoResponse, algorithmName string) ([]response.AlgoResponse, error) {
    validated := make([]response.AlgoResponse, 0, len(responses))
    
    for i, resp := range responses {
        if resp == nil {
            log.Warning("algorithm %s returned nil response at index %d", algorithmName, i)
            continue
        }
        
        score := resp.GetScore()
        if math.IsNaN(score) || math.IsInf(score, 0) {
            log.Warning("algorithm %s returned invalid score %f at index %d", algorithmName, score, i)
            continue
        }
        
        validated = append(validated, resp)
    }
    
    return validated, nil
}
```

### Fallback Response Generation

Provide default responses when algorithms fail:

```go
type FallbackResponse struct {
    score float64
    reason string
}

func (r *FallbackResponse) GetScore() float64 {
    return r.score
}

func (r *FallbackResponse) GetScoreMap() map[string]float64 {
    return map[string]float64{
        "fallback_score": r.score,
    }
}

func (r *FallbackResponse) GetModuleType() bool {
    return false
}

func createFallbackResponses(inputSize int, defaultScore float64) []response.AlgoResponse {
    responses := make([]response.AlgoResponse, inputSize)
    for i := range responses {
        responses[i] = &FallbackResponse{
            score:  defaultScore,
            reason: "algorithm_failure",
        }
    }
    return responses
}

func robustAlgorithmRun(algorithmName string, inputData interface{}) []response.AlgoResponse {
    responses, err := safeProcessResponse(algorithmName, inputData)
    if err != nil {
        log.Error("Algorithm %s failed: %v", algorithmName, err)
        
        // Determine input size for fallback
        inputSize := getInputSize(inputData)
        return createFallbackResponses(inputSize, 0.5)  // Neutral score
    }
    
    return responses
}
```

## Multi-Algorithm Response Combination

### Weighted Combination

Combine scores from multiple algorithms with different weights:

```go
type CombinedResponse struct {
    score       float64
    scoreMap    map[string]float64
    algorithms  []string
    weights     []float64
}

func (r *CombinedResponse) GetScore() float64 {
    return r.score
}

func (r *CombinedResponse) GetScoreMap() map[string]float64 {
    return r.scoreMap
}

func combineResponses(responseGroups [][]response.AlgoResponse, weights []float64, algorithmNames []string) []response.AlgoResponse {
    if len(responseGroups) == 0 {
        return nil
    }
    
    numItems := len(responseGroups[0])
    combined := make([]response.AlgoResponse, numItems)
    
    for i := 0; i < numItems; i++ {
        var weightedScore float64
        var totalWeight float64
        combinedScoreMap := make(map[string]float64)
        
        for j, responses := range responseGroups {
            if i < len(responses) && responses[i] != nil {
                score := responses[i].GetScore()
                weight := weights[j]
                
                weightedScore += score * weight
                totalWeight += weight
                
                // Combine score maps
                if scoreMap := responses[i].GetScoreMap(); scoreMap != nil {
                    for key, value := range scoreMap {
                        combinedKey := fmt.Sprintf("%s_%s", algorithmNames[j], key)
                        combinedScoreMap[combinedKey] = value
                    }
                }
            }
        }
        
        finalScore := 0.5  // Default
        if totalWeight > 0 {
            finalScore = weightedScore / totalWeight
        }
        
        combinedScoreMap["final_score"] = finalScore
        
        combined[i] = &CombinedResponse{
            score:      finalScore,
            scoreMap:   combinedScoreMap,
            algorithms: algorithmNames,
            weights:    weights,
        }
    }
    
    return combined
}

// Usage example
func hybridRecommendation(userID string, candidates []string) []response.AlgoResponse {
    // Get responses from multiple algorithms
    cfResponses := robustAlgorithmRun("collaborative-filter", cfInput)
    contentResponses := robustAlgorithmRun("content-similarity", contentInput)
    popularityResponses := robustAlgorithmRun("popularity-ranker", popularityInput)
    
    // Combine with different weights
    responseGroups := [][]response.AlgoResponse{cfResponses, contentResponses, popularityResponses}
    weights := []float64{0.5, 0.3, 0.2}
    algorithmNames := []string{"collaborative", "content", "popularity"}
    
    return combineResponses(responseGroups, weights, algorithmNames)
}
```

### Ensemble Strategies

Implement different combination strategies beyond simple weighted averages:

```go
// Rank-based combination (Borda count)
func combineByRanks(responseGroups [][]response.AlgoResponse) []response.AlgoResponse {
    numItems := len(responseGroups[0])
    rankScores := make([]float64, numItems)
    
    for _, responses := range responseGroups {
        // Sort by score to get ranks
        ranked := make([]int, len(responses))
        sortedIndices := sortResponsesByScore(responses)
        
        for rank, idx := range sortedIndices {
            ranked[idx] = len(responses) - rank  // Higher rank for higher scores
        }
        
        // Add rank scores
        for i, rank := range ranked {
            rankScores[i] += float64(rank)
        }
    }
    
    // Convert back to responses
    combined := make([]response.AlgoResponse, numItems)
    maxRankScore := float64(numItems * len(responseGroups))
    
    for i, rankScore := range rankScores {
        combined[i] = &CombinedResponse{
            score: rankScore / maxRankScore,  // Normalize to [0, 1]
            scoreMap: map[string]float64{
                "rank_score": rankScore,
            },
        }
    }
    
    return combined
}

// Multiplicative combination
func combineMultiplicative(responseGroups [][]response.AlgoResponse) []response.AlgoResponse {
    numItems := len(responseGroups[0])
    combined := make([]response.AlgoResponse, numItems)
    
    for i := 0; i < numItems; i++ {
        product := 1.0
        count := 0
        
        for _, responses := range responseGroups {
            if i < len(responses) && responses[i] != nil {
                score := responses[i].GetScore()
                product *= score
                count++
            }
        }
        
        // Geometric mean
        finalScore := 0.5
        if count > 0 {
            finalScore = math.Pow(product, 1.0/float64(count))
        }
        
        combined[i] = &CombinedResponse{
            score: finalScore,
            scoreMap: map[string]float64{
                "geometric_mean": finalScore,
            },
        }
    }
    
    return combined
}
```

## Performance Considerations

### Memory Optimization

Efficient response handling for large result sets:

```go
// Use object pools for frequently created responses
var responsePool = sync.Pool{
    New: func() interface{} {
        return &StandardResponse{}
    },
}

func getPooledResponse() *StandardResponse {
    return responsePool.Get().(*StandardResponse)
}

func returnPooledResponse(resp *StandardResponse) {
    resp.reset()  // Clear data
    responsePool.Put(resp)
}

// Stream processing for large response sets
func streamProcessResponses(responses []response.AlgoResponse, processor func(response.AlgoResponse)) {
    for _, resp := range responses {
        processor(resp)
        // Process immediately, don't accumulate
    }
}
```

### Lazy Evaluation

Compute expensive response fields only when needed:

```go
type LazyResponse struct {
    score       float64
    scoreMapFn  func() map[string]float64  // Computed on demand
    computed    bool
    cachedMap   map[string]float64
}

func (r *LazyResponse) GetScore() float64 {
    return r.score
}

func (r *LazyResponse) GetScoreMap() map[string]float64 {
    if !r.computed && r.scoreMapFn != nil {
        r.cachedMap = r.scoreMapFn()
        r.computed = true
    }
    return r.cachedMap
}
```

### Parallel Processing

Process responses from multiple algorithms concurrently:

```go
func parallelAlgorithmExecution(algorithms []string, inputData interface{}) [][]response.AlgoResponse {
    resultChan := make(chan []response.AlgoResponse, len(algorithms))
    errorChan := make(chan error, len(algorithms))
    
    // Execute algorithms in parallel
    for _, algoName := range algorithms {
        go func(name string) {
            responses, err := safeProcessResponse(name, inputData)
            if err != nil {
                errorChan <- err
                return
            }
            resultChan <- responses
        }(algoName)
    }
    
    // Collect results
    results := make([][]response.AlgoResponse, 0, len(algorithms))
    for i := 0; i < len(algorithms); i++ {
        select {
        case responses := <-resultChan:
            results = append(results, responses)
        case err := <-errorChan:
            log.Error("Algorithm execution failed: %v", err)
            // Add fallback responses or skip
        }
    }
    
    return results
}
```

## Best Practices

### 1. **Consistent Response Structure**

Always implement the complete interface, even if some methods return nil:

```go
// ✅ Good: Complete interface implementation
type MyResponse struct {
    score float64
}

func (r *MyResponse) GetScore() float64 {
    return r.score
}

func (r *MyResponse) GetScoreMap() map[string]float64 {
    return nil  // Explicitly return nil for single-score responses
}

func (r *MyResponse) GetModuleType() bool {
    return false
}

// ❌ Bad: Incomplete implementation causes runtime errors
type IncompleteResponse struct {
    score float64
}

func (r *IncompleteResponse) GetScore() float64 {
    return r.score
}
// Missing GetScoreMap() and GetModuleType() methods
```

### 2. **Score Range Consistency**

Ensure scores are in a consistent range across all algorithms:

```go
// ✅ Good: Normalize scores to [0, 1] range
func normalizeScore(rawScore float64, algorithm string) float64 {
    switch algorithm {
    case "collaborative-filter":
        return math.Max(0, math.Min(1, rawScore))  // Clamp to [0, 1]
    case "vector-similarity":
        return (rawScore + 1) / 2  // Convert [-1, 1] to [0, 1]
    case "neural-ranker":
        return sigmoid(rawScore)   // Apply sigmoid for unbounded scores
    default:
        return rawScore
    }
}

// ❌ Bad: Inconsistent score ranges
// CF returns [0, 1], vector returns [-1, 1], neural returns unbounded
```

### 3. **Error Resilience**

Handle edge cases gracefully:

```go
// ✅ Good: Robust response processing
func safeGetScore(resp response.AlgoResponse) float64 {
    if resp == nil {
        return 0.5  // Default neutral score
    }
    
    score := resp.GetScore()
    if math.IsNaN(score) || math.IsInf(score, 0) {
        return 0.5  // Replace invalid scores
    }
    
    return math.Max(0, math.Min(1, score))  // Clamp to valid range
}

// ❌ Bad: No error checking
func unsafeGetScore(resp response.AlgoResponse) float64 {
    return resp.GetScore()  // Can panic or return NaN/Inf
}
```

### 4. **Memory Management**

Avoid memory leaks in long-running services:

```go
// ✅ Good: Clear references after processing
func processResponseBatch(responses []response.AlgoResponse) []ScoredItem {
    items := make([]ScoredItem, len(responses))
    
    for i, resp := range responses {
        items[i] = extractScoredItem(resp)
        responses[i] = nil  // Clear reference to help GC
    }
    
    return items
}

// ✅ Good: Use appropriate data structures
func buildScoreIndex(responses []response.AlgoResponse) map[string]float64 {
    // Pre-allocate with known capacity
    index := make(map[string]float64, len(responses))
    
    for i, resp := range responses {
        key := fmt.Sprintf("item_%d", i)
        index[key] = resp.GetScore()
    }
    
    return index
}
```

### 5. **Debugging and Monitoring**

Include metadata for troubleshooting:

```go
type DebuggableResponse struct {
    response.AlgoResponse
    metadata map[string]interface{}
}

func (r *DebuggableResponse) GetDebugInfo() map[string]interface{} {
    return r.metadata
}

func wrapWithDebugInfo(resp response.AlgoResponse, algorithm string) *DebuggableResponse {
    return &DebuggableResponse{
        AlgoResponse: resp,
        metadata: map[string]interface{}{
            "algorithm":      algorithm,
            "timestamp":      time.Now().Unix(),
            "score_computed": time.Now(),
            "version":        getAlgorithmVersion(algorithm),
        },
    }
}
```

---

## Summary

Response handling in PaiRec provides a powerful, flexible framework for:

- **Uniform interfaces** that work across all algorithm types
- **Rich multi-dimensional scoring** with GetScoreMap()
- **Custom response processing** for algorithm-specific formats
- **Robust error handling** with fallback strategies
- **Multi-algorithm combination** with various ensemble methods
- **Performance optimization** through lazy evaluation and pooling

### Key Takeaways

1. **All algorithms return AlgoResponse interface** for consistent processing
2. **GetScore() provides primary ranking score**, GetScoreMap() enables multi-criteria ranking
3. **Custom response functions** transform raw algorithm outputs to structured responses
4. **Combination strategies** enable powerful ensemble methods
5. **Error handling and fallbacks** ensure system resilience

### Next Steps

- **[Configuration Guide](07-configuration.md)** - Master algorithm configuration patterns
- **[Custom Algorithms](08-custom-algorithms.md)** - Build algorithms with custom response types
- **[Performance Optimization](09-performance.md)** - Optimize response processing for production
- **[API Reference](10-api-reference.md)** - Complete interface documentation