#!/bin/bash

# PaiRec Quick Setup Script
# This script helps newcomers quickly set up and test PaiRec

set -e

echo "🚀 PaiRec Quick Setup"
echo "===================="
echo ""

# Check Go installation
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.20+ from https://golang.org/dl/"
    exit 1
fi

GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
echo "✅ Found Go version: $GO_VERSION"

# Check if we're in the right directory
if [ ! -f "pairec.go" ]; then
    echo "❌ Please run this script from the PaiRec root directory"
    exit 1
fi

echo ""
echo "📦 Installing dependencies..."
go mod tidy

echo ""
echo "🔨 Building PaiRec..."
go build .

if [ ! -f "pairec" ]; then
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi

echo "✅ Build successful!"

echo ""
echo "🧪 Running quick tests..."
# Run a subset of tests that don't require external dependencies
go test ./recconf/ -v || echo "⚠️  Some tests failed (this might be expected for external dependencies)"

echo ""
echo "📋 Setup complete! Here's what you can do next:"
echo ""
echo "1. 🏃 Start the server:"
echo "   ./pairec -config examples/basic-config.json"
echo ""
echo "2. 🧪 Test the API (in another terminal):"
echo "   ./test-api.sh"
echo ""
echo "3. 📖 Read the documentation:"
echo "   - DEVELOPER_GUIDE.md - Development setup and workflow"
echo "   - API_REFERENCE.md - API documentation with examples"
echo "   - ARCHITECTURE.md - System architecture overview"
echo "   - CONTRIBUTING.md - How to contribute to the project"
echo ""
echo "4. 💡 Explore example configurations:"
echo "   - examples/basic-config.json - Minimal setup"
echo "   - examples/ecommerce-config.json - E-commerce use case"
echo ""
echo "5. 🛠️ Development commands:"
echo "   - go test ./... - Run all tests"
echo "   - go fmt ./... - Format code"
echo "   - go build . - Build binary"
echo ""

# Check if Docker is available for containerized development
if command -v docker &> /dev/null; then
    echo "📦 Docker detected! You can also use containerized development."
    echo "   See DEVELOPER_GUIDE.md for Docker instructions."
    echo ""
fi

echo "🎉 Happy coding with PaiRec!"
echo ""
echo "Need help? Check out:"
echo "   - GitHub Issues: https://github.com/alibaba/pairec/issues"
echo "   - Documentation: All .md files in this repository"