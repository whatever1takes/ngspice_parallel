#!/bin/bash

# NGSpice Parallel CMake Build Script
# This script provides a convenient way to build the project using CMake

set -e  # Exit on any error

# Default values
BUILD_TYPE="Release"
BUILD_DIR="build"
CLEAN_BUILD=false
RUN_TESTS=false
INSTALL=false
PACKAGE=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    cat << EOF
NGSpice Parallel CMake Build Script

Usage: $0 [options]

Options:
    -h, --help          Show this help message
    -d, --debug         Build in Debug mode (default: Release)
    -c, --clean         Clean build directory before building
    -t, --test          Run tests after building
    -i, --install       Install after building
    -p, --package       Create distribution package
    -v, --verbose       Verbose build output
    --build-dir DIR     Specify build directory (default: build)

Examples:
    $0                  # Basic release build
    $0 -d -t           # Debug build with tests
    $0 -c -i           # Clean build and install
    $0 --debug --test --verbose  # Debug build with tests and verbose output

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -t|--test)
            RUN_TESTS=true
            shift
            ;;
        -i|--install)
            INSTALL=true
            shift
            ;;
        -p|--package)
            PACKAGE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --build-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if CMake is available
if ! command -v cmake &> /dev/null; then
    print_error "CMake is not installed or not in PATH"
    exit 1
fi

print_status "NGSpice Parallel CMake Build"
print_status "Build Type: $BUILD_TYPE"
print_status "Build Directory: $BUILD_DIR"
print_status "Platform: $(uname -s) $(uname -m)"

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_status "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
print_status "Configuring with CMake..."
CMAKE_ARGS=(
    "-DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    ".."
)

if [ "$VERBOSE" = true ]; then
    CMAKE_ARGS+=("-DCMAKE_VERBOSE_MAKEFILE=ON")
fi

cmake "${CMAKE_ARGS[@]}"

# Build
print_status "Building..."
if [ "$VERBOSE" = true ]; then
    cmake --build . --config "$BUILD_TYPE" -- VERBOSE=1
else
    cmake --build . --config "$BUILD_TYPE"
fi

print_success "Build completed successfully!"

# Prepare runtime libraries
print_status "Preparing runtime libraries..."
cmake --build . --target prepare-libs

# Run tests if requested
if [ "$RUN_TESTS" = true ]; then
    print_status "Running tests..."
    cmake --build . --target run-test
    print_success "Tests completed!"
fi

# Install if requested
if [ "$INSTALL" = true ]; then
    print_status "Installing..."
    cmake --build . --target install
    print_success "Installation completed!"
fi

# Create package if requested
if [ "$PACKAGE" = true ]; then
    print_status "Creating package..."
    cpack
    print_success "Package created!"
fi

# Show final status
echo ""
print_success "All operations completed successfully!"
echo ""
print_status "Available executables:"
if [ -f "ng_shared_parallel_test" ]; then
    echo "  ./ng_shared_parallel_test"
fi

print_status "Available targets:"
echo "  cmake --build . --target prepare-libs    # Prepare runtime libraries"
echo "  cmake --build . --target run-test        # Run the test program"
echo "  cmake --build . --target install         # Install the program"
echo "  cpack                                     # Create distribution package"

echo ""
print_status "To run the program manually:"
echo "  cd $BUILD_DIR"
echo "  ./ng_shared_parallel_test"
