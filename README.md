# PaiRec

A comprehensive Go web framework for quickly building high-performance recommendation systems based on JSON configuration. PaiRec provides a modular, scalable architecture that supports various machine learning algorithms, data sources, and deployment scenarios.

## ✨ Features

- **🚀 High Performance**: Built with Go for optimal speed and concurrency
- **🔧 Configuration-Driven**: JSON-based configuration for easy customization
- **🧩 Modular Architecture**: Pluggable components for recall, ranking, filtering, and sorting
- **🤖 ML Integration**: Support for TensorFlow, PyTorch, Milvus, Faiss, and more
- **📊 Multiple Data Sources**: MySQL, Redis, HBase, ClickHouse, Kafka, and others
- **🔍 A/B Testing**: Built-in experiment management and traffic splitting
- **📈 Monitoring**: Prometheus metrics and comprehensive logging
- **🌐 Cloud Native**: Designed for Alibaba Cloud and multi-cloud deployments

## 🚀 Quick Start

### Installation
```bash
go get github.com/alibaba/pairec/v2
```

### Basic Usage
```bash
# Clone the repository
git clone https://github.com/alibaba/pairec.git
cd pairec

# Install dependencies
go mod tidy

# Create a basic configuration
cat > config.json << EOF
{
  "listen_conf": {
    "http_port": 8000,
    "http_addr": "0.0.0.0"
  },
  "scene_confs": [
    {
      "scene_id": "homepage",
      "recall_names": [],
      "filter_names": [],
      "sort_names": []
    }
  ]
}
EOF

# Build and run
go build .
./pairec -config config.json
```

### Test the API
```bash
# Health check
curl http://localhost:8000/ping

# Get recommendations
curl -X POST http://localhost:8000/api/recommend \
  -H "Content-Type: application/json" \
  -d '{"scene_id": "homepage", "uid": "user123", "size": 10}'
```

## 📚 Documentation

### For Newcomers
- **[Tutorial](TUTORIAL.md)** - Beginner-friendly guide to PaiRec's key abstractions and concepts
- **[Developer Guide](DEVELOPER_GUIDE.md)** - Complete onboarding guide for new contributors
- **[API Reference](API_REFERENCE.md)** - Comprehensive API documentation with examples
- **[Architecture Overview](ARCHITECTURE.md)** - System design and component details

### For Contributors
- **[Contributing Guidelines](CONTRIBUTING.md)** - Development practices and PR process
- **[中文技术文档](https://help.aliyun.com/zh/airec/basic-introduction-1?spm=a2c4g.11186623.0.0.3a8c3672NtpB9B)** - Chinese documentation

## 🏗️ Architecture

PaiRec follows a layered, modular architecture:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web APIs      │    │   A/B Testing   │    │   Monitoring    │
│                 │    │                 │    │                 │
│ • Recommend     │    │ • Experiments   │    │ • Prometheus    │
│ • Recall        │    │ • Traffic Split │    │ • Logging       │
│ • Features      │    │ • Config Mgmt   │    │ • Health Check  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────────────────────────────────────────────────────┐
│                    Core Services                                │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐│
│  │   Recall    │  │   Filter    │  │    Rank     │  │  Sort   ││
│  │             │  │             │  │             │  │         ││
│  │ • Collab.   │  │ • Quality   │  │ • ML Models │  │ • Score ││
│  │ • Content   │  │ • Diversity │  │ • Deep Net  │  │ • Rules ││
│  │ • Vector    │  │ • Business  │  │ • Ensemble  │  │ • Boost ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘│
└─────────────────────────────────────────────────────────────────┘
         │                       │                       │
┌─────────────────────────────────────────────────────────────────┐
│                   Algorithm & Data Layer                        │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐│
│  │ ML Engines  │  │   Storage   │  │   Compute   │  │  Cache  ││
│  │             │  │             │  │             │  │         ││
│  │ • EAS       │  │ • MySQL     │  │ • TF Serve  │  │ • Redis ││
│  │ • Milvus    │  │ • HBase     │  │ • PyTorch   │  │ • Memory││
│  │ • Faiss     │  │ • ClickHs   │  │ • ONNX      │  │ • Local ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Key Components

- **Recall**: Multi-source candidate generation (collaborative filtering, content-based, vector similarity)
- **Filter**: Business rule application (quality, diversity, constraints)  
- **Rank**: ML-powered scoring (deep learning, ensemble methods)
- **Sort**: Final result ordering (score-based, rule-based, hybrid)

## 🌟 Use Cases

- **E-commerce**: Product recommendations, cross-selling, upselling
- **Content Platforms**: Article, video, music recommendations
- **Social Networks**: Friend suggestions, content feeds
- **News & Media**: Personalized content delivery
- **Gaming**: Item recommendations, matchmaking

## 🛠️ Supported Technologies

### Machine Learning
- **TensorFlow Serving** - Production ML model serving
- **PyTorch/TorchServe** - Deep learning model deployment  
- **ONNX Runtime** - Cross-platform model inference
- **Scikit-learn** - Traditional ML algorithms

### Vector Databases
- **Milvus** - Open-source vector similarity search
- **Faiss** - Facebook AI similarity search library
- **Alibaba Cloud OpenSearch** - Managed search service

### Data Sources
- **Relational**: MySQL, PostgreSQL
- **NoSQL**: HBase, MongoDB, DynamoDB
- **Cache**: Redis, Memcached
- **Analytics**: ClickHouse, Apache Druid
- **Streaming**: Kafka, Pulsar, DataHub

## 🚀 Production Deployments

PaiRec is production-ready and supports:
- **Container Deployment**: Docker, Kubernetes
- **Cloud Platforms**: Alibaba Cloud, AWS, Azure, GCP
- **Service Mesh**: Istio integration
- **Auto Scaling**: Based on traffic and resource usage
- **Multi-Region**: Global deployment with data locality

## 📊 Performance

- **High Throughput**: 10K+ QPS per instance
- **Low Latency**: <50ms P99 response time
- **Memory Efficient**: Optimized for large-scale deployments
- **Horizontal Scalable**: Linear scaling with cluster size

## 🤝 Community & Support

- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: Community Q&A and best practices
- **Documentation**: Comprehensive guides and API docs
- **Examples**: Sample configurations and use cases

## 📜 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Built with ❤️ by the Alibaba recommendation systems team and open source contributors.

---

**Getting Started**: Check out our [Tutorial](TUTORIAL.md) to understand PaiRec's key abstractions, then follow our [Developer Guide](DEVELOPER_GUIDE.md) to quickly start contributing to PaiRec!
