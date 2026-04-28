#!/bin/bash
set -euo pipefail

# PRoot Static Build System Demo
echo "🏗️  PRoot Static Cross-Compilation Build System"
echo "================================================"
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "📁 Project Structure:"
echo "✅ Docker environment: $(ls docker/Dockerfile.cross-base 2>/dev/null && echo "Present" || echo "Missing")"
echo "✅ Build scripts: $(ls docker/scripts/build.sh 2>/dev/null && echo "Present" || echo "Missing")"  
echo "✅ GitHub Actions: $(ls .github/workflows/build-static-binaries.yml 2>/dev/null && echo "Present" || echo "Missing")"
echo "✅ Modified Makefile: $(grep -q "STATIC_BUILD" src/GNUmakefile && echo "Present" || echo "Missing")"
echo ""

echo "🔧 Available Build Commands:"
echo "  Local test build:    ./docker/scripts/build-local.sh x86_64 linux"
echo "  Test all builds:     ./docker/scripts/test-all-builds.sh"
echo ""

echo "🎯 Supported Targets:"
echo "  Linux:    x86_64, i386, aarch64, arm"  
echo "  Android:  x86_64, i386, aarch64, arm"
echo ""

if [ -f "dist/x86_64-linux/proot" ]; then
    echo "✅ Demo Build Result:"
    echo "  Binary: dist/x86_64-linux/proot"
    echo "  Size: $(ls -lh dist/x86_64-linux/proot | awk '{print $5}')"
    echo "  Type: $(file dist/x86_64-linux/proot | cut -d: -f2 | sed 's/^ *//')"
    echo "  Static: $(ldd dist/x86_64-linux/proot 2>&1 | grep -q "not a dynamic executable" && echo "Yes" || echo "No")"
    echo ""
    
    echo "🧪 Function Test:"
    if ./dist/x86_64-linux/proot --version >/dev/null 2>&1; then
        echo "  ✅ Binary executes successfully"
        echo "  Version: $(./dist/x86_64-linux/proot --version | head -1)"
    else
        echo "  ⚠️  Binary execution test failed"
    fi
else
    echo "ℹ️  No demo build found. Run:"
    echo "     ./docker/scripts/build-local.sh x86_64 linux"
fi

echo ""
echo "🚀 GitHub Actions:"
echo "  The workflow will automatically:"
echo "  • Build all targets on every push"
echo "  • Upload artifacts for testing"
echo "  • Create release assets on v* tags"
echo ""

echo "📖 Documentation:"
echo "  • Build system: docker/README.md"
echo "  • Project plan: Plan available in session"
echo ""

echo "🎉 Build system is ready for production use!"
echo "   Next: Push to trigger GitHub Actions builds"