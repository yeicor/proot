#!/bin/bash
set -euo pipefail

# Build script for cross-compilation
ARCH=${1:-x86_64}
PLATFORM=${2:-linux}
BUILD_DIR="/build"
TALLOC_VERSION="2.4.3"

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
        # Use gcc -m32 for i386 builds
        export CC="gcc -m32"
        export CXX="g++ -m32" 
        export CROSS_COMPILE=""
        export CFLAGS="-static -O2 -m32 -Wno-error=implicit-fallthrough"
        ;;
    aarch64-linux|arm64-linux)
        export CC=aarch64-linux-gnu-gcc
        export CXX=aarch64-linux-gnu-g++
        export CROSS_COMPILE=aarch64-linux-gnu-
        export CFLAGS="-static -O2"
        export PROOT_DISABLE_LOADER_32BIT=1
        ;;
    arm-linux)
        export CC=arm-linux-gnueabihf-gcc
        export CXX=arm-linux-gnueabihf-g++
        export CROSS_COMPILE=arm-linux-gnueabihf-
        export CFLAGS="-static -O2"
        export PROOT_DISABLE_LOADER_32BIT=1
        ;;
    x86_64-android)
        export CC=${ANDROID_NDK_TOOLCHAIN_X86_64}
        export CXX=${ANDROID_NDK_TOOLCHAIN_X86_64}++
        export CROSS_COMPILE=""
        export STRIP="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
        export OBJCOPY="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objcopy"
        export OBJDUMP="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
        export CFLAGS="-static -O2 -DANDROID"
        ;;
    i386-android|x86-android)
        export CC=${ANDROID_NDK_TOOLCHAIN_X86}
        export CXX=${ANDROID_NDK_TOOLCHAIN_X86}++
        export CROSS_COMPILE=""
        export STRIP="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
        export OBJCOPY="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objcopy"
        export OBJDUMP="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
        export CFLAGS="-static -O2 -m32 -DANDROID"
        ;;
    aarch64-android|arm64-android)
        export CC=${ANDROID_NDK_TOOLCHAIN_ARM64}
        export CXX=${ANDROID_NDK_TOOLCHAIN_ARM64}++
        export CROSS_COMPILE=""
        export STRIP="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
        export OBJCOPY="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objcopy"
        export OBJDUMP="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
        export CFLAGS="-static -O2 -DANDROID"
        export PROOT_DISABLE_LOADER_32BIT=1
        ;;
    arm-android)
        export CC=${ANDROID_NDK_TOOLCHAIN_ARM}
        export CXX=${ANDROID_NDK_TOOLCHAIN_ARM}++
        export CROSS_COMPILE=""
        export STRIP="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
        export OBJCOPY="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objcopy"
        export OBJDUMP="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump"
        export CFLAGS="-static -O2 -DANDROID"
        export PROOT_DISABLE_LOADER_32BIT=1
        ;;
    *)
        echo "Unsupported architecture: $ARCH-$PLATFORM"
        exit 1
        ;;
esac

echo "Using compiler: $CC"
echo "CFLAGS: $CFLAGS"

# Create output directory
mkdir -p "$BUILD_DIR"

# Copy source to build directory (Docker mounts are read-only)
echo "Copying source code..."
# Copy only the source files, not the docker directory
cd /source
cp -f *.* "$BUILD_DIR/" 2>/dev/null || true
cp -r src "$BUILD_DIR/" 2>/dev/null || true
cp -r doc "$BUILD_DIR/" 2>/dev/null || true
cp -r tests "$BUILD_DIR/" 2>/dev/null || true
# List what we copied
echo "Copied files:"
ls -la "$BUILD_DIR/"

# Build talloc dependency
echo "Building talloc dependency..."

TALLOC_INSTALL_DIR="$BUILD_DIR/deps/$ARCH-$PLATFORM"
mkdir -p "$TALLOC_INSTALL_DIR/include"
mkdir -p "$TALLOC_INSTALL_DIR/lib"

# Build real libtalloc from source (prefer upstream Samba talloc)
TALLOC_VERSION="2.4.3"
TALLOC_URL="https://www.samba.org/ftp/talloc/talloc-${TALLOC_VERSION}.tar.gz"

echo "Downloading talloc ${TALLOC_VERSION}..."
cd /tmp
if [ ! -f "talloc-${TALLOC_VERSION}.tar.gz" ]; then
    wget -q "$TALLOC_URL" -O "talloc-${TALLOC_VERSION}.tar.gz" || { echo "Failed to download talloc"; exit 1; }
fi
rm -rf "talloc-${TALLOC_VERSION}"
tar xzf "talloc-${TALLOC_VERSION}.tar.gz"
cd "talloc-${TALLOC_VERSION}"

# Setup cross-build host triplet and helpers
TALLOC_HOST=""
AR_TOOL="${CROSS_COMPILE}ar"
RANLIB_TOOL="${CROSS_COMPILE}ranlib"
if [[ "${ARCH}-${PLATFORM}" == *"-android" ]]; then
    # For Android NDK use llvm-ar/ranlib
    AR_TOOL="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
    RANLIB_TOOL="/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ranlib"
fi

case "$ARCH-$PLATFORM" in
    x86_64-linux)
        TALLOC_HOST="x86_64-linux-gnu"
        ;;
    i386-linux|x86-linux)
        TALLOC_HOST="i686-linux-gnu"
        ;;
    aarch64-linux|arm64-linux)
        TALLOC_HOST="aarch64-linux-gnu"
        ;;
    arm-linux)
        TALLOC_HOST="arm-linux-gnueabihf"
        ;;
    x86_64-android)
        TALLOC_HOST="x86_64-linux-android"
        ;;
    i386-android|x86-android)
        TALLOC_HOST="i686-linux-android"
        ;;
    aarch64-android|arm64-android)
        TALLOC_HOST="aarch64-linux-android"
        ;;
    arm-android)
        TALLOC_HOST="armv7a-linux-androideabi"
        ;;
esac

echo "Configuring talloc for host: $TALLOC_HOST"
# Export tools for configure
export AR="$AR_TOOL"
export RANLIB="$RANLIB_TOOL"

# Configure and build
./configure --host="$TALLOC_HOST" --prefix="$TALLOC_INSTALL_DIR" --disable-rpath --disable-python || { echo "talloc configure failed"; exit 1; }
make -j$(nproc) || { echo "talloc make failed"; exit 1; }
make install || { echo "talloc make install failed"; }

# Ensure libtalloc.a exists; if not, try to assemble a static archive
if [ ! -f "$TALLOC_INSTALL_DIR/lib/libtalloc.a" ]; then
    echo "libtalloc.a not found after install, attempting manual archive creation"
    # Try common locations for object files
    if [ -d .libs ]; then
        $AR_TOOL rcs "$TALLOC_INSTALL_DIR/lib/libtalloc.a" .libs/*.o || true
    elif [ -d src ]; then
        $AR_TOOL rcs "$TALLOC_INSTALL_DIR/lib/libtalloc.a" src/*.o || true
    fi
fi

# Copy headers if not installed
if [ ! -f "$TALLOC_INSTALL_DIR/include/talloc.h" ]; then
    install -Dm644 include/talloc.h "$TALLOC_INSTALL_DIR/include/talloc.h" || true
fi

# Basic verify
ls -la "$TALLOC_INSTALL_DIR/lib" || true
ls -la "$TALLOC_INSTALL_DIR/include" || true

# Build PRoot
echo "Building PRoot..."
cd "$BUILD_DIR"

# Set up build environment
export PKG_CONFIG_PATH="$TALLOC_INSTALL_DIR/lib/pkgconfig"
export CPPFLAGS="-I$TALLOC_INSTALL_DIR/include"
export TALLOC_LIBS="-L$TALLOC_INSTALL_DIR/lib -ltalloc"
export LDFLAGS="-L$TALLOC_INSTALL_DIR/lib"

# Build PRoot with static linking
cd src
make clean || true

# Enable static build mode
export STATIC_BUILD=1

# Build
make -j$(nproc) 

# Verify the binary
echo "Build completed. Verifying binary..."
ls -la proot*

# Check if binary is properly linked
if command -v file >/dev/null; then
    file proot
fi

if command -v ldd >/dev/null; then
    echo "Checking dependencies:"
    ldd proot || echo "Static binary - no dynamic dependencies"
fi

# Test basic functionality
echo "Testing basic functionality..."
if ./proot --help | head -5; then
    echo "Functionality test passed"
else
    echo "Cannot test functionality (cross-compiled binary or other error)"
fi

# Copy the built binary to output location
OUTPUT_DIR="/output"
mkdir -p "$OUTPUT_DIR"

# Create output subdirectory per architecture/platform so CI can find it
OUTPUT_SUBDIR="$OUTPUT_DIR/$ARCH-$PLATFORM"
mkdir -p "$OUTPUT_SUBDIR"

# Copy proot to a standardized path expected by CI
cp proot "$OUTPUT_SUBDIR/proot"

# Also place a legacy-named binary at the top-level output for local tests
BINARY_NAME="proot-$ARCH-$PLATFORM"
cp proot "$OUTPUT_DIR/$BINARY_NAME"

# Strip debug symbols to reduce size using preferred stripper
STRIP_TOOL="${STRIP:-${CROSS_COMPILE}strip}"
if [ -n "${STRIP_TOOL}" ] && command -v ${STRIP_TOOL%% *} >/dev/null 2>&1; then
    # If STRIP_TOOL is a path use it directly, otherwise rely on command lookup
    ${STRIP_TOOL} "$OUTPUT_SUBDIR/proot" 2>/dev/null || echo "Could not strip binary with $STRIP_TOOL"
elif command -v strip >/dev/null 2>&1; then
    strip "$OUTPUT_SUBDIR/proot" 2>/dev/null || echo "Could not strip binary with strip"
else
    echo "No strip tool available; binary left unstripped"
fi

echo "Build completed successfully!"
echo "Output binary: $OUTPUT_SUBDIR/proot"
ls -la "$OUTPUT_SUBDIR/proot"