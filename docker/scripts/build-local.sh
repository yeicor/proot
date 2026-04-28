#!/bin/bash
set -euo pipefail

# Local build script for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default values
ARCH=${1:-x86_64}
PLATFORM=${2:-linux}
DOCKER_IMAGE="proot-cross-builder"

echo "Building PRoot for $ARCH-$PLATFORM"
echo "Project root: $PROJECT_ROOT"

# Build the Docker image
echo "Building Docker image..."
docker build -t "$DOCKER_IMAGE" -f "$PROJECT_ROOT/docker/Dockerfile.cross-base" "$PROJECT_ROOT"

# Create output directory
OUTPUT_DIR="$PROJECT_ROOT/dist"
mkdir -p "$OUTPUT_DIR"

# Run the build in Docker
echo "Starting build in container..."
docker run --rm \
    -v "$PROJECT_ROOT:/source:ro" \
    -v "$PROJECT_ROOT/docker/scripts:/build/scripts:ro" \
    -v "$OUTPUT_DIR:/output" \
    "$DOCKER_IMAGE" \
    "$ARCH" "$PLATFORM"

echo "Build completed! Output in: $OUTPUT_DIR/$ARCH-$PLATFORM/"
ls -la "$OUTPUT_DIR/$ARCH-$PLATFORM/" || true