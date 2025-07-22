# PaiRec Architecture Overview

PaiRec is a Go-based web framework designed for building high-performance recommendation systems. This document provides a comprehensive overview of the system architecture, core components, and data flow patterns.

## High-Level Architecture

PaiRec follows a modular, layered architecture that separates concerns between data ingestion, feature processing, algorithm execution, and result serving.

```
┌─────────────────────────────────────────────────────────────┐
│                        Web Layer                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐│
│  │   Recommend     │  │   User Recall   │  │   Feature    ││
│  │   Controller    │  │   Controller    │  │   Reply      ││
│  └─────────────────┘  └─────────────────┘  └──────────────┘│
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐│
│  │   Recommend     │  │     Recall      │  │    Feature   ││
│  │   Service       │  │    Service      │  │   Service    ││
│  └─────────────────┘  └─────────────────┘  └──────────────┘│
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                    Processing Layer                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐│
│  │    Algorithms   │  │     Filters     │  │    Sorting   ││
│  │  (ML/AI Models) │  │   (Business     │  │  (Ranking)   ││
│  │                 │  │    Rules)       │  │              ││
│  └─────────────────┘  └─────────────────┘  └──────────────┘│
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐│
│  │   DataSources   │  │   Persistence   │  │   A/B Test   ││
│  │ (MySQL, Redis,  │  │  (Logging,      │  │   Config     ││
│  │  HBase, etc.)   │  │   Metrics)      │  │   Manager    ││
│  └─────────────────┘  └─────────────────┘  └──────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Web Layer (`/web`)
The web layer provides HTTP endpoints for recommendation services:

- **RecommendController**: Main recommendation API endpoint (`/api/recommend`)
- **UserRecallController**: User-based item recall API (`/api/recall`)
- **FeatureReplyController**: Feature processing API (`/api/feature_reply`)
- **CallBackController**: Feedback and logging endpoint (`/api/callback`)
- **EmbeddingController**: Vector embedding services (`/api/embedding`)

### 2. Service Layer (`/service`)
Core business logic components:

- **RecommendService**: Orchestrates the recommendation pipeline
- **RecallService**: Handles candidate item retrieval and generation
- **FeatureService**: Manages feature extraction and processing
- **RankService**: Implements ranking algorithms and models
- **PipelineService**: Manages recommendation workflow pipelines

### 3. Algorithm Layer (`/algorithm`)
Machine learning and AI model integrations:

- **EAS (Elastic Algorithm Service)**: Alibaba Cloud ML model serving
- **TensorFlow Serving**: TensorFlow model integration
- **Milvus**: Vector similarity search and retrieval
- **Faiss**: Facebook AI Similarity Search library
- **Seldon**: Multi-cloud ML model deployment

### 4. Data Sources (`/datasource`)
Data connectivity and retrieval:

- **MySQL**: Relational database connectivity
- **Redis**: In-memory caching and storage
- **HBase**: Distributed NoSQL database
- **ClickHouse**: Columnar analytics database  
- **Kafka**: Stream processing and messaging
- **OpenSearch**: Search and analytics engine
- **Feature Store**: Centralized feature management

### 5. Processing Components

#### Filtering (`/filter`)
Business rule-based content filtering:
- Duplicate removal
- Quality filtering
- Business constraint enforcement
- User preference filtering

#### Sorting (`/sort`)
Result ranking and ordering:
- Score-based sorting
- Diversity optimization
- Business rule application
- Multi-criteria ranking

### 6. Configuration Management (`/recconf`)
Centralized configuration system:
- Scene-specific configurations
- A/B test parameter management
- Dynamic configuration updates
- Feature flag management

### 7. Persistence Layer (`/persist`)
Data persistence and logging:
- **MySQL**: Structured data storage
- **Redis**: Caching layer
- **ClickHouse**: Analytics and metrics
- **TableStore**: NoSQL document storage
- **Feature Store**: Feature metadata

## Data Flow Architecture

### Request Processing Flow

```
HTTP Request
    │
    ▼
┌───────────────────┐
│  Web Controller   │
│                   │
│ • Parse Request   │
│ • Validate Input  │
│ • Extract Context │
└───────────────────┘
    │
    ▼
┌───────────────────┐
│  Service Layer    │
│                   │
│ • Load User Data  │
│ • Feature Eng.    │
│ • Context Setup   │
└───────────────────┘
    │
    ▼
┌───────────────────┐
│   Recall Phase    │
│                   │
│ • Candidate Gen.  │
│ • Multi-source    │
│ • Merge & Dedupe  │
└───────────────────┘
    │
    ▼
┌───────────────────┐
│   Filter Phase    │
│                   │
│ • Business Rules  │
│ • Quality Filter  │
│ • User Preferences│
└───────────────────┘
    │
    ▼
┌───────────────────┐
│    Rank Phase     │
│                   │
│ • ML Model Score  │
│ • Feature Compute │
│ • Score Normalize │
└───────────────────┘
    │
    ▼
┌───────────────────┐
│    Sort Phase     │
│                   │
│ • Final Ranking   │
│ • Diversity Opt.  │
│ • Business Logic  │
└───────────────────┘
    │
    ▼
┌───────────────────┐
│  HTTP Response    │
│                   │
│ • Format Results  │
│ • Log Metrics     │
│ • Return JSON     │
└───────────────────┘
```

### Configuration and A/B Testing

PaiRec supports dynamic configuration and A/B testing through:

1. **Configuration Sources**:
   - Local JSON files (`-config` flag)
   - Remote config server (via `CONFIG_NAME` env var)
   - Environment variables

2. **A/B Testing**:
   - Experiment configuration management
   - Traffic splitting
   - Feature flag management
   - Metrics collection

### Monitoring and Observability

- **Prometheus Metrics**: Available at `/metrics` endpoint
- **Custom Metrics**: Available at `/custom_metrics` endpoint
- **Structured Logging**: Request tracing and debugging
- **Health Checks**: Available at `/ping` endpoint

## Design Patterns

### 1. Plugin Architecture
Components use plugin-style registration:
```go
// Example from algorithm loading
algorithm.Load(recconf.Config)
filter.Load(recconf.Config)
sort.Load(recconf.Config)
```

### 2. Context Pattern
Request context flows through the entire pipeline:
```go
type RecommendContext struct {
    RecommendId string
    User        *User
    Scene       string
    Parameters  map[string]interface{}
}
```

### 3. Pipeline Pattern
Processing stages are chained:
```
Recall → Filter → Rank → Sort → Response
```

### 4. Factory Pattern
Components are created based on configuration:
- Data source factories
- Algorithm factories
- Service factories

## Scalability Considerations

### Horizontal Scaling
- Stateless service design
- External configuration management
- Distributed caching with Redis
- Load balancer friendly

### Performance Optimization
- Connection pooling for databases
- In-memory caching strategies
- Asynchronous processing where applicable
- Efficient data serialization

### Resource Management
- Configurable timeouts
- Circuit breaker patterns
- Resource pooling
- Memory management for large datasets

## Security Architecture

- Input validation and sanitization
- Authentication middleware support
- Secure configuration management
- Audit logging capabilities

This architecture provides a robust foundation for building scalable, maintainable recommendation systems while allowing for extensive customization and integration with various data sources and ML frameworks.