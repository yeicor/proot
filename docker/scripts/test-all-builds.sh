#!/bin/bash
set -euo pipefail

# Test all builds locally
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Testing PRoot cross-compilation builds..."

# Build the Docker image first
echo "Building Docker image..."
cd "$PROJECT_ROOT"
docker build -t proot-cross-builder -f docker/Dockerfile.cross-base .

# Create output directory
mkdir -p dist

# Test configurations
declare -a CONFIGS=(
    "x86_64 linux"
    "i386 linux" 
    "aarch64 linux"
    "arm linux"
    "x86_64 android"
    "i386 android"
    "aarch64 android"
    "arm android"
)

# Build each configuration
for config in "${CONFIGS[@]}"; do
    read -r arch platform <<< "$config"
    echo "========================================="
    echo "Building: $arch-$platform"
    echo "========================================="
    
    docker run --rm \
        -v "$PROJECT_ROOT:/source:ro" \
        -v "$PROJECT_ROOT/docker/scripts:/build/scripts:ro" \
        -v "$PROJECT_ROOT/dist:/output" \
        proot-cross-builder \
        "$arch" "$platform"
    
    if [ -f "dist/$arch-$platform/proot" ]; then
        echo "✓ Build successful: $arch-$platform"
        file "dist/$arch-$platform/proot"
        ls -la "dist/$arch-$platform/proot"
        echo ""
    else
        echo "✗ Build failed: $arch-$platform"
    fi
done

echo "========================================="
echo "Build Summary:"
echo "========================================="
find dist -name "proot" -exec echo "Found: {}" \; -exec file {} \; -exec ls -la {} \;

echo ""
echo "All builds completed! Check the dist/ directory for outputs."