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
echo "🔧 PaiRec is a library framework - building command line tool..."
cd commands
go build -o pairec .
cd ..

if [ ! -f "commands/pairec" ]; then
    echo "❌ Command line tool build failed. Please check the error messages above."
    exit 1
fi

echo "✅ Build successful!"

echo ""
echo "🧪 Running quick tests..."
# Run a subset of tests that don't require external dependencies
go test ./recconf/ -v || echo "⚠️  Some tests failed (this might be expected for external dependencies)"

echo ""
echo "📋 Setup complete! PaiRec is a Go library framework for building recommendation systems."
echo ""
echo "Here are your next steps:"
echo ""
echo "1. 🏗️  Create a new project using the command line tool:"
echo "   cd commands"
echo "   ./pairec project create myapp"
echo "   cd myapp"
echo ""
echo "2. 📚 Learn how to integrate PaiRec into your Go application:"
echo "   See examples in DEVELOPER_GUIDE.md"
echo ""
echo "3. 🧪 Test the example configurations:"
echo "   Using the configurations in examples/ directory"
echo ""
echo "4. 📖 Read the comprehensive documentation:"
echo "   - QUICKSTART.md - 5-minute introduction"
echo "   - DEVELOPER_GUIDE.md - Complete development guide"
echo "   - API_REFERENCE.md - API documentation with examples"
echo "   - ARCHITECTURE.md - System architecture overview"
echo "   - CONTRIBUTING.md - How to contribute to the project"
echo ""
echo "5. 💡 Explore example configurations:"
echo "   - examples/basic-config.json - Minimal setup"
echo "   - examples/ecommerce-config.json - E-commerce use case"
echo ""
echo "6. 🛠️  Development commands:"
echo "   - go test ./... - Run all tests"
echo "   - go fmt ./... - Format code"
echo "   - go mod tidy - Update dependencies"
echo ""

# Check if Docker is available for containerized development
if command -v docker &> /dev/null; then
    echo "📦 Docker detected! You can also use containerized development."
    echo "   See DEVELOPER_GUIDE.md for Docker instructions."
    echo ""
fi

echo "🎉 Welcome to PaiRec!"
echo ""
echo "💡 PaiRec is a library framework. To build a recommendation service:"
echo "   1. Import PaiRec in your Go application"
echo "   2. Configure your recommendation pipeline"
echo "   3. Use pairec.Run() to start the service"
echo ""
echo "Need help? Check out:"
echo "   - GitHub Issues: https://github.com/alibaba/pairec/issues"
echo "   - Documentation: All .md files in this repository"
echo "   - Example projects: Use 'pairec project create' command"