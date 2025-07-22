# PaiRec Algorithm Framework Documentation

Welcome to the comprehensive guide for PaiRec's algorithm framework! This documentation provides both a beginner-friendly tutorial and detailed technical reference for understanding, using, and extending PaiRec's machine learning algorithms.

## 📚 Documentation Structure

### For Beginners
1. **[Core Concepts](01-core-concepts.md)** - Understanding PaiRec's algorithm abstractions
2. **[Getting Started](02-getting-started.md)** - Your first algorithm integration
3. **[Simple Algorithms](03-simple-algorithms.md)** - LOOKUP algorithm walkthrough

### Algorithm Deep Dives
4. **[Vector Search Algorithms](04-vector-search.md)** - FAISS and Milvus for similarity search
5. **[ML Serving Algorithms](05-ml-serving.md)** - EAS, TensorFlow Serving, and Seldon
6. **[Response Handling](06-response-handling.md)** - Understanding algorithm outputs

### Advanced Topics
7. **[Configuration Guide](07-configuration.md)** - Detailed configuration options
8. **[Custom Algorithms](08-custom-algorithms.md)** - Building your own algorithms
9. **[Performance & Optimization](09-performance.md)** - Best practices and tuning
10. **[API Reference](10-api-reference.md)** - Complete technical reference

## 🎯 Quick Navigation

### By Use Case
- **Vector Similarity Search**: [FAISS](04-vector-search.md#faiss) | [Milvus](04-vector-search.md#milvus)
- **ML Model Serving**: [EAS](05-ml-serving.md#eas) | [TensorFlow Serving](05-ml-serving.md#tensorflow-serving) | [Seldon](05-ml-serving.md#seldon)
- **Simple Scoring**: [LOOKUP](03-simple-algorithms.md)
- **Custom Integration**: [Custom Algorithms](08-custom-algorithms.md)

### By Algorithm Type
- **[EAS (Elastic Algorithm Service)](05-ml-serving.md#eas)** - Alibaba Cloud's ML serving platform
- **[FAISS](04-vector-search.md#faiss)** - Facebook AI Similarity Search
- **[LOOKUP](03-simple-algorithms.md)** - Feature-based score lookup
- **[Milvus](04-vector-search.md#milvus)** - Open-source vector database
- **[Seldon](05-ml-serving.md#seldon)** - Seldon Core ML platform
- **[TensorFlow Serving](05-ml-serving.md#tensorflow-serving)** - TensorFlow model serving

## 🚀 Quick Start

If you're new to PaiRec algorithms, start here:

```go
// 1. Understand the core interface
type IAlgorithm interface {
    Init(conf *recconf.AlgoConfig) error
    Run(algoData interface{}) (interface{}, error)
}

// 2. Use the factory to run algorithms
result, err := algorithm.Run("my-algorithm", inputData)
```

📖 **Next Steps**: Read [Core Concepts](01-core-concepts.md) to understand the fundamental design principles.

## 🔧 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Algorithm Factory                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              IAlgorithm Interface                   │   │
│  │   Init(config) + Run(data) → AlgoResponse          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
           │                    │                    │
  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
  │ Vector Search  │   │   ML Serving   │   │ Simple Lookup  │
  │                │   │                │   │                │
  │ • FAISS        │   │ • EAS          │   │ • LOOKUP       │
  │ • Milvus       │   │ • TF Serving   │   │                │
  │                │   │ • Seldon       │   │                │
  └────────────────┘   └────────────────┘   └────────────────┘
```

## 📋 Prerequisites

- **Go 1.18+** for building and running
- **Basic ML Knowledge** for algorithm-specific concepts
- **JSON Configuration** familiarity for setup

## 🤝 Contributing

Found an issue or want to improve the documentation? See our [contribution guidelines](../../CONTRIBUTING.md) and feel free to submit pull requests!

## 💡 Support

- **📖 Documentation Issues**: Open a GitHub issue with the `documentation` label
- **🐛 Code Issues**: Open a GitHub issue with the `bug` label  
- **💬 Questions**: Use GitHub Discussions for community support

---

**Happy coding!** 🎉 Start your journey with [Core Concepts](01-core-concepts.md).