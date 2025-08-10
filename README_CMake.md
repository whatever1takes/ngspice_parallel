# NGSpice Parallel - CMake Build System

This document describes how to use the CMake build system for the NGSpice Parallel project. The CMake system provides a modern, cross-platform build solution that's ideal for integration into larger projects.

## Overview

The CMake build system offers several advantages over the traditional Makefile:

- **Cross-platform**: Works on Linux, macOS, and Windows
- **IDE Integration**: Generates project files for various IDEs (Visual Studio, Xcode, etc.)
- **Dependency Management**: Automatic detection of NGSpice libraries and headers
- **Modern Build**: Uses modern CMake practices and targets
- **Packaging**: Built-in support for creating distribution packages
- **Testing**: Integrated test targets

## Quick Start

### Using the Build Script (Recommended)

The easiest way to build the project is using the provided build script:

```bash
# Basic build
./build.sh

# Debug build with tests
./build.sh --debug --test

# Clean build and install
./build.sh --clean --install

# Show help
./build.sh --help
```

### Manual CMake Commands

If you prefer to use CMake directly:

```bash
# Create build directory
mkdir build && cd build

# Configure
cmake ..

# Build
cmake --build .

# Prepare runtime libraries
cmake --build . --target prepare-libs

# Run tests
cmake --build . --target run-test
```

## Build Options

### Build Types

- **Release** (default): Optimized build (`-O2 -DNDEBUG`)
- **Debug**: Debug build with symbols (`-g -DDEBUG -O0`)

```bash
# Debug build
cmake -DCMAKE_BUILD_TYPE=Debug ..

# Release build
cmake -DCMAKE_BUILD_TYPE=Release ..
```

### Custom Installation Prefix

```bash
cmake -DCMAKE_INSTALL_PREFIX=/usr/local ..
```

## Available Targets

| Target | Description |
|--------|-------------|
| `ng_shared_parallel_test` | Build the main executable |
| `prepare-libs` | Copy NGSpice libraries for runtime |
| `run-test` | Build and run the test program |
| `install` | Install the program and documentation |
| `package` | Create distribution packages |

### Building Specific Targets

```bash
# Build only the executable
cmake --build . --target ng_shared_parallel_test

# Prepare runtime libraries
cmake --build . --target prepare-libs

# Run tests
cmake --build . --target run-test

# Install
cmake --build . --target install

# Create packages
cmake --build . --target package
```

## Dependencies

The CMake system automatically detects and configures dependencies:

### Required Dependencies
- **C Compiler**: GCC, Clang, or MSVC with C99 support
- **CMake**: Version 3.12 or higher
- **Threads**: POSIX threads (pthread)
- **Dynamic Loading**: libdl (Linux) or system libraries (macOS/Windows)

### Optional Dependencies
- **NGSpice**: For full functionality
  - Headers: `ngspice/sharedspice.h`
  - Library: `libngspice.so` (Linux) or `libngspice.dylib` (macOS)

### Installing NGSpice

#### Linux
```bash
# Ubuntu/Debian
sudo apt-get install ngspice libngspice0-dev

# CentOS/RHEL
sudo yum install ngspice ngspice-devel

# Fedora
sudo dnf install ngspice ngspice-devel
```

#### macOS
```bash
# MacPorts
sudo port install ngspice +lib+manual

# Homebrew
brew install ngspice
```

## Project Structure

```
ngspice_parallel/
├── CMakeLists.txt              # Main CMake configuration
├── build.sh                    # Convenient build script
├── README_CMake.md             # This file
├── cmake/                      # CMake modules and scripts
│   ├── FindNGSpice.cmake       # NGSpice detection module
│   └── PrepareLibs.cmake       # Runtime library preparation
├── build/                      # Build directory (created by CMake)
│   ├── ng_shared_parallel_test # Compiled executable
│   ├── libngspice*.so          # Runtime libraries
│   └── examples/               # Test circuit files
├── include/                    # Header files
├── ng_shared_parallel/         # Source files
└── examples/                   # Test circuit files
```

## Integration with Larger Projects

### As a Subdirectory

Add this project as a subdirectory in your larger CMake project:

```cmake
# In your main CMakeLists.txt
add_subdirectory(ngspice_parallel)

# Link against the target
target_link_libraries(your_target ng_shared_parallel_test)
```

### Using find_package()

Install the project and use it as a package:

```cmake
# Install the project first
cmake --build . --target install

# In your project
find_package(ngspice_parallel REQUIRED)
target_link_libraries(your_target ngspice_parallel::ng_shared_parallel_test)
```

### As an External Project

```cmake
include(ExternalProject)
ExternalProject_Add(ngspice_parallel
    GIT_REPOSITORY https://github.com/your-repo/ngspice_parallel.git
    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/external
)
```

## Configuration Variables

The CMake system provides several configuration options:

| Variable | Description | Default |
|----------|-------------|---------|
| `CMAKE_BUILD_TYPE` | Build type (Debug/Release) | Release |
| `CMAKE_INSTALL_PREFIX` | Installation directory | /usr/local |
| `NGSpice_ROOT` | NGSpice installation root | Auto-detected |

### Example Configuration

```bash
cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_INSTALL_PREFIX=/opt/ngspice_parallel \
    -DNGSpice_ROOT=/usr/local \
    ..
```

## Packaging

The CMake system includes CPack configuration for creating distribution packages:

```bash
# Create packages
cmake --build . --target package

# Available formats (Linux)
cpack -G DEB    # Debian package
cpack -G RPM    # RPM package
cpack -G TGZ    # Tar.gz archive

# Available formats (macOS)
cpack -G TGZ    # Tar.gz archive
cpack -G ZIP    # Zip archive
```

## Troubleshooting

### NGSpice Not Found

If CMake cannot find NGSpice:

1. Install NGSpice development packages
2. Set the `NGSpice_ROOT` variable:
   ```bash
   cmake -DNGSpice_ROOT=/path/to/ngspice ..
   ```

### Build Errors

1. Check CMake version: `cmake --version` (requires 3.12+)
2. Verify compiler: `gcc --version` or `clang --version`
3. Check dependencies: `./test_compilation.sh`

### Runtime Issues

1. Ensure examples directory exists in build directory
2. Check that `libngspice*.so` files are present
3. Verify NGSpice library compatibility

## Comparison with Makefile

| Feature | CMake | Makefile |
|---------|-------|----------|
| Cross-platform | ✅ | ❌ |
| IDE Integration | ✅ | ❌ |
| Dependency Detection | ✅ | Manual |
| Modern Build System | ✅ | ❌ |
| Package Creation | ✅ | ❌ |
| Large Project Integration | ✅ | Limited |

Both build systems are maintained and functional. Use CMake for modern development and integration, use Makefile for simple builds and traditional workflows.

## Platform-Specific Library Handling

### Linux (.so files)
The CMake system automatically handles Linux shared libraries:

- **Detection**: Searches for `libngspice.so` in standard locations:
  - `/usr/lib/libngspice.so`
  - `/usr/lib/x86_64-linux-gnu/libngspice.so`
  - `/usr/lib/aarch64-linux-gnu/libngspice.so`
  - `/usr/lib64/libngspice.so`
  - `/usr/local/lib/libngspice.so`

- **Runtime Preparation**: Creates three copies as `.so` files:
  - `libngspice1.so`
  - `libngspice2.so`
  - `libngspice3.so`

### macOS (.dylib files)
The CMake system handles macOS dynamic libraries with cross-platform compatibility:

- **Detection**: Searches for `libngspice.dylib` in:
  - `/opt/local/lib/libngspice.dylib` (MacPorts)
  - `/usr/local/lib/libngspice.dylib` (Homebrew Intel)
  - `/opt/homebrew/lib/libngspice.dylib` (Homebrew Apple Silicon)

- **Runtime Preparation**: Creates symbolic links with `.so` extension for consistency:
  - `libngspice1.so -> /path/to/libngspice.dylib`
  - `libngspice2.so -> /path/to/libngspice.dylib`
  - `libngspice3.so -> /path/to/libngspice.dylib`

This approach ensures that the same `.so` naming convention works across all platforms, making the code portable and consistent.

## Support

For CMake-specific issues:
1. Check the CMake documentation: https://cmake.org/documentation/
2. Review the build configuration: `cmake --build . --target config`
3. Use verbose output: `cmake --build . --verbose`

For general project issues, refer to the main README files.
