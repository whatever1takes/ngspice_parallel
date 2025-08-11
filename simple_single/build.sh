#!/bin/bash

set -e

echo "=========================================="
echo "Simple Single Thread NGSpice Build"
echo "=========================================="

# Create build directory
BUILD_DIR="build"
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi

mkdir "$BUILD_DIR"
cd "$BUILD_DIR"

# Copy circuit file
cp ../test_circuit.cir .

echo "Configuring with CMake..."
cmake ..

echo "Building..."
make

echo ""
echo "=========================================="
echo "Build completed!"
echo "=========================================="
echo ""
echo "To run:"
echo "  cd $BUILD_DIR"
echo "  ./ngspice_simple_single"
echo ""
