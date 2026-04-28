# PRoot Cross-Compilation Build System

This directory contains the Docker-based cross-compilation build system for PRoot, enabling static binary builds for multiple architectures and platforms.

## Supported Targets

### Linux
- x86_64 (64-bit Intel/AMD)
- i386 (32-bit Intel/AMD)
- aarch64 (64-bit ARM)
- arm (32-bit ARM)

### Android
- x86_64 (64-bit Intel/AMD)
- i386 (32-bit Intel/AMD) 
- aarch64 (64-bit ARM)
- arm (32-bit ARM)

## Features

- **Static Builds**: All binaries are statically linked and have no external dependencies
- **From-Source Dependencies**: talloc and other dependencies are built from source
- **Cross-Compilation**: Uses appropriate toolchains for each target architecture
- **Docker-Based**: Consistent build environment across different host systems
- **GitHub Actions**: Automated builds on every push and release creation

## Quick Start

### Build Single Architecture

```bash
# Build for x86_64 Linux
./docker/scripts/build-local.sh x86_64 linux

# Build for aarch64 Android  
./docker/scripts/build-local.sh aarch64 android
```

### Test All Builds

```bash
# Build all supported architectures and platforms
./docker/scripts/test-all-builds.sh
```

### Manual Docker Build

```bash
# Build the Docker image
docker build -t proot-cross-builder -f docker/Dockerfile.cross-base .

# Run a build
docker run --rm \
  -v $(pwd):/source:ro \
  -v $(pwd)/dist:/output \
  proot-cross-builder \
  x86_64 linux
```

## Build Process

1. **Docker Environment**: Sets up cross-compilation toolchains for all target architectures
2. **Dependency Building**: Compiles talloc from source for each target
3. **Static Compilation**: Links PRoot statically against all dependencies
4. **Binary Stripping**: Removes debug symbols to reduce file size

## GitHub Actions

The workflow automatically:
- Builds on every push to main/master
- Creates artifacts for all architectures
- Publishes release assets when a `v*` tag is created
- Runs basic tests on generated binaries

## Directory Structure

```
docker/
├── Dockerfile.cross-base      # Cross-compilation environment
└── scripts/
    ├── build.sh               # Main build script
    ├── build-local.sh         # Local testing script  
    └── test-all-builds.sh     # Test all configurations
```

## Dependencies

- **talloc**: Memory pool allocator (built from source)
- **Cross-compilation toolchains**: GCC cross-compilers and Android NDK
- **Docker**: For consistent build environments

## Output

Built binaries are placed in `dist/ARCH-PLATFORM/proot` and are:
- Statically linked (no external dependencies)
- Stripped of debug symbols
- Ready for distribution

## Troubleshooting

### Build Failures

1. Check Docker is running and has sufficient resources
2. Ensure internet connectivity for downloading dependencies
3. Review build logs for specific compilation errors

### Missing Architectures

Some architectures may require additional toolchain setup or may not be supported on all host systems.

### Testing Binaries

```bash
# Check if binary is statically linked (Linux)
ldd dist/x86_64-linux/proot

# Basic functionality test
dist/x86_64-linux/proot --help
```

## Contributing

When adding new architectures or modifying the build system:

1. Update the build matrix in `.github/workflows/build-static-binaries.yml`
2. Add toolchain configuration in `docker/scripts/build.sh`
3. Test locally with `test-all-builds.sh`
4. Update this documentation

## License

This build system is provided under the same license as PRoot itself.