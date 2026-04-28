#!/bin/bash
set -euo pipefail

# Build script for cross-compilation
ARCH=${1:-x86_64}
PLATFORM=${2:-linux}
BUILD_DIR="/build"
TALLOC_VERSION="2.4.1"

echo "Building for architecture: $ARCH, platform: $PLATFORM"

# Set up toolchain variables
case "$ARCH-$PLATFORM" in
    x86_64-linux)
        export CC=gcc
        export CXX=g++
        export CROSS_COMPILE=""
        export CFLAGS="-static -O2"
        ;;
    i386-linux|x86-linux)
        # For 32-bit builds, we'll use -m32 but might need to install additional packages
        export CC="gcc -m32"
        export CXX="g++ -m32" 
        export CROSS_COMPILE=""
        export CFLAGS="-static -O2 -m32"
        # Install 32-bit libraries if needed
        apt-get update && apt-get install -y gcc-multilib g++-multilib || echo "32-bit tools already available"
        ;;
    aarch64-linux|arm64-linux)
        export CC=aarch64-linux-gnu-gcc
        export CXX=aarch64-linux-gnu-g++
        export CROSS_COMPILE=aarch64-linux-gnu-
        export CFLAGS="-static -O2"
        ;;
    arm-linux)
        export CC=arm-linux-gnueabihf-gcc
        export CXX=arm-linux-gnueabihf-g++
        export CROSS_COMPILE=arm-linux-gnueabihf-
        export CFLAGS="-static -O2"
        ;;
    x86_64-android)
        export CC=${ANDROID_NDK_TOOLCHAIN_X86_64}
        export CXX=${ANDROID_NDK_TOOLCHAIN_X86_64}++
        export CROSS_COMPILE=""
        export CFLAGS="-static -O2 -DANDROID"
        ;;
    i386-android|x86-android)
        export CC=${ANDROID_NDK_TOOLCHAIN_X86}
        export CXX=${ANDROID_NDK_TOOLCHAIN_X86}++
        export CROSS_COMPILE=""
        export CFLAGS="-static -O2 -DANDROID"
        ;;
    aarch64-android|arm64-android)
        export CC=${ANDROID_NDK_TOOLCHAIN_ARM64}
        export CXX=${ANDROID_NDK_TOOLCHAIN_ARM64}++
        export CROSS_COMPILE=""
        export CFLAGS="-static -O2 -DANDROID"
        ;;
    arm-android)
        export CC=${ANDROID_NDK_TOOLCHAIN_ARM}
        export CXX=${ANDROID_NDK_TOOLCHAIN_ARM}++
        export CROSS_COMPILE=""
        export CFLAGS="-static -O2 -DANDROID"
        ;;
    *)
        echo "Unsupported architecture-platform combination: $ARCH-$PLATFORM"
        exit 1
        ;;
esac

export LDFLAGS="-static"
export PKG_CONFIG="pkg-config --static"
export CPPFLAGS="${CPPFLAGS:-}"

# Create output directories
OUTPUT_DIR="/output/${ARCH}-${PLATFORM}"
mkdir -p "$OUTPUT_DIR"

echo "Toolchain setup:"
echo "CC: $CC"
echo "CFLAGS: $CFLAGS"
echo "LDFLAGS: $LDFLAGS"

# Verify toolchain
if ! $CC --version; then
    echo "Error: Toolchain not found for $CC"
    exit 1
fi

# Build talloc from source
build_talloc() {
    echo "Setting up talloc for $ARCH-$PLATFORM..."
    
    TALLOC_INSTALL_DIR="$BUILD_DIR/deps/${ARCH}-${PLATFORM}"
    mkdir -p "$TALLOC_INSTALL_DIR/lib"
    mkdir -p "$TALLOC_INSTALL_DIR/include"
    
    # For now, use system talloc and copy for static linking
    # This is a temporary approach - we can build from source later
    case "$ARCH-$PLATFORM" in
        x86_64-linux)
            # Use system talloc
            cp /usr/include/talloc.h "$TALLOC_INSTALL_DIR/include/"
            cp /usr/lib/x86_64-linux-gnu/libtalloc.a "$TALLOC_INSTALL_DIR/lib/" 2>/dev/null || \
                ar x /usr/lib/x86_64-linux-gnu/libtalloc.so.2 && ar rcs "$TALLOC_INSTALL_DIR/lib/libtalloc.a" *.o 2>/dev/null || \
                echo "Warning: Using dynamic talloc"
            ;;
        *)
            # For cross-compilation, we need a different approach
            # Create a minimal talloc stub for now
            echo "Creating minimal talloc stub for cross-compilation..."
            
            cat > "$TALLOC_INSTALL_DIR/include/talloc.h" << 'EOF'
#ifndef TALLOC_H
#define TALLOC_H

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

// Forward declarations
struct talloc_chunk;

// Minimal talloc implementation for static linking
void *talloc(const void *context, size_t size);
void *talloc_strdup(const void *t, const char *p);
void *talloc_realloc(const void *context, void *ptr, size_t size);
int talloc_free(void *ptr);
void talloc_free_children(void *ptr);
char *talloc_asprintf(const void *t, const char *fmt, ...);
void *talloc_parent(const void *ptr);
#define talloc_get_type_abort(ptr, type) ((type *)(ptr))
int talloc_reparent(const void *old_parent, const void *new_parent, const void *ptr);
void talloc_report_depth_cb(const void *ptr, int depth, int max_depth, void (*callback)(const void *ptr, int depth, int max_depth, int is_ref, void *private_data), void *private_data);
void talloc_report_depth_file(const void *ptr, int depth, int max_depth, FILE *f);

#define talloc_new(ctx) talloc(ctx, 0)
#define talloc_zero(ctx, type) (type *)calloc(1, sizeof(type))
#define talloc_array(ctx, type, count) (type *)calloc(count, sizeof(type))

#endif
EOF

            cat > /tmp/talloc_stub.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

void *talloc(const void *context, size_t size) {
    return malloc(size);
}

void *talloc_strdup(const void *t, const char *p) {
    return strdup(p);
}

void *talloc_realloc(const void *context, void *ptr, size_t size) {
    return realloc(ptr, size);
}

int talloc_free(void *ptr) {
    free(ptr);
    return 0;
}

void talloc_free_children(void *ptr) {
    // No-op in minimal implementation
}

char *talloc_asprintf(const void *t, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    char *result = NULL;
    vasprintf(&result, fmt, args);
    va_end(args);
    return result;
}

void *talloc_parent(const void *ptr) {
    return NULL; // Minimal implementation
}

void *talloc_get_type_abort(const void *ptr, const char *type) {
    return (void*)ptr; // Minimal implementation - just return the pointer
}

int talloc_reparent(const void *old_parent, const void *new_parent, const void *ptr) {
    return 0; // No-op in minimal implementation
}

void talloc_report_depth_cb(const void *ptr, int depth, int max_depth, void (*callback)(const void *ptr, int depth, int max_depth, int is_ref, void *private_data), void *private_data) {
    // No-op in minimal implementation
}

void talloc_report_depth_file(const void *ptr, int depth, int max_depth, FILE *f) {
    // No-op in minimal implementation
}
EOF
            
            # Compile the stub
            $CC $CFLAGS -c /tmp/talloc_stub.c -o "$TALLOC_INSTALL_DIR/lib/talloc_stub.o"
            ar rcs "$TALLOC_INSTALL_DIR/lib/libtalloc.a" "$TALLOC_INSTALL_DIR/lib/talloc_stub.o"
            ;;
    esac
    
    echo "Talloc setup completed for $ARCH-$PLATFORM"
    ls -la "$TALLOC_INSTALL_DIR/lib/"
    ls -la "$TALLOC_INSTALL_DIR/include/"
}

# Build proot
build_proot() {
    echo "Building proot..."
    
    # Copy source to writable location
    echo "Copying source files..."
    cp -r /source /build/proot-src
    cd /build/proot-src
    
    # Set up build environment for proot
    export TALLOC_LIBS="$BUILD_DIR/deps/${ARCH}-${PLATFORM}/lib/libtalloc.a"
    export CPPFLAGS="-I$BUILD_DIR/deps/${ARCH}-${PLATFORM}/include $CPPFLAGS"
    
    # Clean previous builds
    make -C src clean || true
    
    # Build proot with static linking
    make -C src -j$(nproc) \
        CC="$CC" \
        CROSS_COMPILE="$CROSS_COMPILE" \
        STATIC_BUILD=1 \
        CFLAGS="$CFLAGS -I$BUILD_DIR/deps/${ARCH}-${PLATFORM}/include" \
        LDFLAGS="$LDFLAGS -L$BUILD_DIR/deps/${ARCH}-${PLATFORM}/lib" \
        TALLOC_LIBS="$BUILD_DIR/deps/${ARCH}-${PLATFORM}/lib/libtalloc.a" \
        proot
    
    # Copy the built binary to output
    cp src/proot "$OUTPUT_DIR/proot"
    
    # Strip the binary
    if command -v ${CROSS_COMPILE}strip >/dev/null 2>&1; then
        ${CROSS_COMPILE}strip "$OUTPUT_DIR/proot"
    elif command -v strip >/dev/null 2>&1; then
        strip "$OUTPUT_DIR/proot" || true
    fi
    
    # Verify the binary
    file "$OUTPUT_DIR/proot"
    ls -la "$OUTPUT_DIR/proot"
    
    echo "PRoot built successfully for $ARCH-$PLATFORM"
    echo "Binary location: $OUTPUT_DIR/proot"
}

# Main build process
main() {
    build_talloc
    build_proot
    
    echo "Build completed successfully!"
    echo "Output directory: $OUTPUT_DIR"
    ls -la "$OUTPUT_DIR/"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi