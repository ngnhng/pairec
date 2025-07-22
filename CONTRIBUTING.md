# Contributing to PaiRec

We welcome contributions to PaiRec! This guide outlines the development practices, coding standards, and contribution process to help you contribute effectively.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Standards](#documentation-standards)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please be respectful and professional in all interactions.

## Getting Started

### Prerequisites
- Go 1.20+
- Git
- Understanding of recommendation systems (helpful but not required)

### Development Setup
1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/pairec.git
   cd pairec
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/alibaba/pairec.git
   ```
4. Install dependencies:
   ```bash
   go mod tidy
   ```
5. Verify the setup:
   ```bash
   go build .
   go test ./...
   ```

## Development Process

### Issue Workflow
1. **Check existing issues** before creating a new one
2. **Use issue templates** when available
3. **Label issues** appropriately (bug, feature, documentation, etc.)
4. **Assign yourself** to issues you're working on

### Branch Naming Convention
- `feature/description` - For new features
- `bugfix/issue-number` - For bug fixes  
- `docs/description` - For documentation changes
- `refactor/description` - For code refactoring

### Commit Message Format
Follow the conventional commit format:

```
type(scope): brief description

Detailed description (if needed)

Fixes #issue-number
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(recall): add collaborative filtering algorithm

Implement user-based collaborative filtering with configurable 
similarity metrics and neighbor selection.

Fixes #123
```

```
fix(web): handle missing user ID in recommend API

Add validation to check for required uid parameter and return
appropriate error message when missing.

Fixes #456
```

## Coding Standards

### Go Style Guide
Follow the [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments) and these additional guidelines:

#### Code Formatting
```bash
# Format code before committing
go fmt ./...

# Use goimports for import management
goimports -w .

# Run linter
golangci-lint run
```

#### Naming Conventions
- **Packages**: short, lowercase, single word
- **Interfaces**: noun ending with "er" (e.g., `Reader`, `Writer`)
- **Functions**: MixedCaps, descriptive names
- **Variables**: camelCase, avoid abbreviations
- **Constants**: MixedCaps or ALL_CAPS for package-level constants

#### Good Examples
```go
// Good: Clear, descriptive names
type UserRecommender interface {
    GetRecommendations(ctx context.Context, userID string) ([]*Item, error)
}

func (r *RecallService) GetCandidateItems(user *User, count int) ([]*Item, error) {
    // Implementation
}

// Good: Clear error handling
func (s *Service) ProcessUser(userID string) error {
    if userID == "" {
        return fmt.Errorf("user ID cannot be empty")
    }
    
    user, err := s.userRepo.GetUser(userID)
    if err != nil {
        return fmt.Errorf("failed to get user %s: %w", userID, err)
    }
    
    return s.processUserData(user)
}
```

#### Avoid
```go
// Avoid: Unclear names and poor error handling
type URS interface {
    Get(id string) ([]*I, error)
}

func (r *RS) GetCI(u *U, c int) ([]*I, error) {
    // Implementation
}

func (s *S) ProcU(id string) error {
    u, err := s.ur.GetU(id)
    if err != nil {
        return err  // Lost context
    }
    return nil
}
```

### Error Handling
- **Always handle errors** appropriately
- **Wrap errors** with context using `fmt.Errorf`
- **Use specific error types** for different error conditions
- **Log errors** at appropriate levels

```go
// Good error handling
func (s *RecommendService) GetItems(userID string) ([]*Item, error) {
    if userID == "" {
        return nil, fmt.Errorf("user ID is required")
    }
    
    items, err := s.dataSource.FetchItems(userID)
    if err != nil {
        log.Error("failed to fetch items", 
            "user_id", userID, 
            "error", err)
        return nil, fmt.Errorf("failed to fetch items for user %s: %w", userID, err)
    }
    
    return items, nil
}
```

### Logging Standards
Use structured logging with appropriate levels:

```go
import "github.com/alibaba/pairec/v2/log"

// Info level for normal operations
log.Info("processing recommendation request",
    "user_id", userID,
    "scene", sceneID,
    "items_count", len(items))

// Error level for errors
log.Error("database connection failed",
    "error", err,
    "retry_count", retryCount)

// Debug level for development
log.Debug("algorithm parameters",
    "learning_rate", lr,
    "epochs", epochs)
```

### Configuration Handling
- **Use structured configuration** with clear field names
- **Validate configuration** on startup
- **Provide sensible defaults**
- **Document configuration options**

```go
type AlgorithmConfig struct {
    Name           string  `json:"name"`
    LearningRate   float64 `json:"learning_rate,omitempty"`   // Optional with default
    MaxIterations  int     `json:"max_iterations,omitempty"`  // Optional with default
    Enabled        bool    `json:"enabled"`                   // Required
}

func (c *AlgorithmConfig) Validate() error {
    if c.Name == "" {
        return fmt.Errorf("algorithm name is required")
    }
    if c.LearningRate <= 0 {
        c.LearningRate = 0.001 // Set default
    }
    return nil
}
```

## Testing Guidelines

### Test Structure
Follow the table-driven test pattern for comprehensive test coverage:

```go
func TestRecommendService_GetRecommendations(t *testing.T) {
    tests := []struct {
        name        string
        userID      string
        sceneID     string
        want        int
        wantErr     bool
        errorString string
    }{
        {
            name:    "valid request",
            userID:  "user123",
            sceneID: "home",
            want:    10,
            wantErr: false,
        },
        {
            name:        "empty user ID",
            userID:      "",
            sceneID:     "home", 
            want:        0,
            wantErr:     true,
            errorString: "user ID is required",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            service := NewRecommendService()
            got, err := service.GetRecommendations(tt.userID, tt.sceneID)
            
            if tt.wantErr {
                assert.Error(t, err)
                if tt.errorString != "" {
                    assert.Contains(t, err.Error(), tt.errorString)
                }
                return
            }
            
            assert.NoError(t, err)
            assert.Equal(t, tt.want, len(got))
        })
    }
}
```

### Test Categories

#### Unit Tests
Test individual functions and methods in isolation:

```go
func TestUserFilter_Filter(t *testing.T) {
    filter := NewUserFilter(map[string]interface{}{
        "min_age": 18,
        "max_age": 65,
    })
    
    users := []*User{
        {ID: "1", Age: 25}, // Valid
        {ID: "2", Age: 16}, // Too young
        {ID: "3", Age: 70}, // Too old
    }
    
    result := filter.Filter(users)
    
    assert.Equal(t, 1, len(result))
    assert.Equal(t, "1", result[0].ID)
}
```

#### Integration Tests
Test component interactions:

```go
func TestRecommendationPipeline(t *testing.T) {
    // Setup test database and dependencies
    db := setupTestDB(t)
    defer db.Close()
    
    service := NewRecommendService(db, testConfig)
    
    // Test full pipeline
    result, err := service.GetRecommendations("user123", "home", 10)
    
    assert.NoError(t, err)
    assert.LessOrEqual(t, len(result), 10)
    
    // Verify result quality
    for _, item := range result {
        assert.NotEmpty(t, item.ID)
        assert.Greater(t, item.Score, 0.0)
    }
}
```

### Mock Usage
Use dependency injection and interfaces for testable code:

```go
//go:generate mockgen -source=interfaces.go -destination=mocks/mock_interfaces.go

type DataSource interface {
    GetItems(userID string) ([]*Item, error)
}

type RecommendService struct {
    dataSource DataSource
}

// In tests
func TestWithMock(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockDS := mocks.NewMockDataSource(ctrl)
    mockDS.EXPECT().GetItems("user123").Return([]*Item{{ID: "1"}}, nil)
    
    service := &RecommendService{dataSource: mockDS}
    result, err := service.GetRecommendations("user123")
    
    assert.NoError(t, err)
    assert.Equal(t, 1, len(result))
}
```

### Test Coverage
- Aim for **>80% test coverage** for new code
- Run coverage reports: `go test -cover ./...`
- Use `go test -coverprofile=coverage.out` for detailed reports

## Documentation Standards

### Code Comments
- **Document public functions** with clear descriptions
- **Use examples** in Go doc comments when helpful
- **Explain complex algorithms** with inline comments

```go
// GetRecommendations returns personalized item recommendations for a user.
// It processes the request through the recall, filter, rank, and sort pipeline.
//
// Parameters:
//   - userID: unique identifier for the user
//   - sceneID: recommendation context/scene identifier  
//   - size: maximum number of items to return
//
// Returns a slice of recommended items ordered by relevance score.
// Returns an error if the user is not found or pipeline processing fails.
//
// Example:
//   items, err := service.GetRecommendations("user123", "homepage", 10)
//   if err != nil {
//       log.Error("recommendation failed", err)
//       return
//   }
func (s *RecommendService) GetRecommendations(userID, sceneID string, size int) ([]*Item, error) {
    // Input validation
    if userID == "" {
        return nil, fmt.Errorf("user ID is required")
    }
    
    // Complex algorithm explanation
    // Use collaborative filtering to find similar users based on
    // interaction history, then recommend items those users liked
    similarUsers := s.findSimilarUsers(userID)
    
    return s.generateRecommendations(similarUsers, size)
}
```

### README Updates
When adding new features, update relevant README sections:
- Installation instructions
- Configuration examples  
- Usage examples
- API changes

## Pull Request Process

### Before Submitting
1. **Sync with upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run quality checks**:
   ```bash
   go fmt ./...
   golangci-lint run
   go test ./...
   go mod tidy
   ```

3. **Update documentation** if needed

4. **Write descriptive commit messages**

### PR Template
Use this template for your pull request description:

```markdown
## Summary
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Documentation
- [ ] Code comments updated
- [ ] README updated (if needed)
- [ ] API documentation updated (if needed)

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests pass locally
- [ ] No new warnings from linter

## Related Issues
Fixes #issue_number
```

### Review Process
1. **Automated checks** must pass (CI/CD)
2. **At least one reviewer** approval required
3. **Address feedback** promptly
4. **Maintain clean commit history** (squash if needed)

## Release Process

### Version Numbering
We follow [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 2.1.0)
- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Release Checklist
1. Update version numbers
2. Update CHANGELOG.md
3. Create release notes
4. Tag release
5. Deploy to staging for testing
6. Deploy to production

## Questions and Support

- **GitHub Issues**: For bugs and feature requests
- **Discussions**: For questions and general discussion
- **Documentation**: Check existing docs first

Thank you for contributing to PaiRec! 🚀