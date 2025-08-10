#!/bin/bash

# Test script to verify compilation works on different systems
# This script performs basic compilation tests without requiring root privileges

set -e

echo "=========================================="
echo "NGSpice Parallel Compilation Test"
echo "=========================================="

# Function to check system information
check_system() {
    echo "System Information:"
    echo "  OS: $(uname -s)"
    echo "  Architecture: $(uname -m)"
    echo "  Kernel: $(uname -r)"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "  Distribution: $PRETTY_NAME"
    fi
    echo ""
}

# Function to check required tools
check_tools() {
    echo "Checking required tools..."
    
    local missing_tools=()
    
    # Check GCC
    if command -v gcc &> /dev/null; then
        echo "✓ GCC: $(gcc --version | head -n1)"
    else
        echo "✗ GCC: Not found"
        missing_tools+=("gcc")
    fi
    
    # Check Make
    if command -v make &> /dev/null; then
        echo "✓ Make: $(make --version | head -n1)"
    else
        echo "✗ Make: Not found"
        missing_tools+=("make")
    fi
    
    # Check for pthread support
    if echo '#include <pthread.h>' | gcc -E - &> /dev/null; then
        echo "✓ pthread: Available"
    else
        echo "✗ pthread: Not available"
        missing_tools+=("pthread")
    fi
    
    # Check for dl support
    if echo '#include <dlfcn.h>' | gcc -E - &> /dev/null; then
        echo "✓ libdl: Available"
    else
        echo "✗ libdl: Not available"
        missing_tools+=("libdl")
    fi
    
    echo ""
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Missing tools: ${missing_tools[*]}"
        echo "Please install the missing tools before proceeding."
        return 1
    fi
    
    return 0
}

# Function to check NGSpice availability
check_ngspice() {
    echo "Checking NGSpice availability..."
    
    # Check NGSpice executable
    if command -v ngspice &> /dev/null; then
        echo "✓ NGSpice executable: $(ngspice --version 2>&1 | head -n1 | cut -d' ' -f1-2)"
    else
        echo "✗ NGSpice executable: Not found"
    fi
    
    # Check for NGSpice libraries
    local lib_found=false
    local lib_paths=("/usr/lib" "/usr/local/lib" "/opt/local/lib" "/opt/homebrew/lib" "/usr/lib/x86_64-linux-gnu" "/usr/lib64")
    
    for lib_path in "${lib_paths[@]}"; do
        if [ -f "$lib_path/libngspice.so" ] || [ -f "$lib_path/libngspice.dylib" ]; then
            echo "✓ NGSpice library found: $lib_path/"
            lib_found=true
            break
        fi
    done
    
    if [ "$lib_found" = false ]; then
        echo "✗ NGSpice library: Not found in standard locations"
        echo "  Searched paths: ${lib_paths[*]}"
    fi
    
    # Check for NGSpice headers
    local header_found=false
    local header_paths=("/usr/include" "/usr/local/include" "/opt/local/include" "/opt/homebrew/include")
    
    for header_path in "${header_paths[@]}"; do
        if [ -f "$header_path/ngspice/sharedspice.h" ]; then
            echo "✓ NGSpice headers found: $header_path/ngspice/"
            header_found=true
            break
        fi
    done
    
    if [ "$header_found" = false ]; then
        echo "✗ NGSpice headers: Not found in standard locations"
        echo "  Searched paths: ${header_paths[*]}"
    fi
    
    echo ""
}

# Function to test basic compilation
test_basic_compilation() {
    echo "Testing basic compilation..."
    
    # Create a simple test program
    cat > test_compile.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <dlfcn.h>

#ifndef _MSC_VER
#include <stdbool.h>
#include <stdint.h>
#else
#define bool int
#define true 1
#define false 0
#endif

int main() {
    printf("Basic compilation test successful!\n");
    printf("pthread support: available\n");
    printf("dlopen support: available\n");
    return 0;
}
EOF

    # Try to compile
    if gcc -std=c99 -Wall -Wextra test_compile.c -o test_compile -lpthread -ldl; then
        echo "✓ Basic compilation: SUCCESS"
        if ./test_compile; then
            echo "✓ Basic execution: SUCCESS"
        else
            echo "✗ Basic execution: FAILED"
        fi
    else
        echo "✗ Basic compilation: FAILED"
        return 1
    fi
    
    # Clean up
    rm -f test_compile.c test_compile
    echo ""
}

# Function to test project compilation
test_project_compilation() {
    echo "Testing project compilation..."
    
    if [ ! -f "Makefile" ]; then
        echo "✗ Makefile not found - are you in the project directory?"
        return 1
    fi
    
    if [ ! -f "ng_shared_parallel/main.c" ]; then
        echo "✗ Source file not found - project structure incomplete"
        return 1
    fi
    
    # Test Makefile configuration
    echo "Makefile configuration:"
    make config 2>/dev/null || echo "  (Configuration check failed)"
    
    # Try to compile without NGSpice library (just syntax check)
    echo ""
    echo "Testing syntax compilation (without NGSpice linking)..."
    
    if gcc -std=c99 -Wall -Wextra -Iinclude -c ng_shared_parallel/main.c -o test_main.o; then
        echo "✓ Syntax compilation: SUCCESS"
        rm -f test_main.o
    else
        echo "✗ Syntax compilation: FAILED"
        return 1
    fi
    
    # Try full compilation if NGSpice is available
    echo ""
    echo "Testing full compilation..."
    
    if make clean && make release 2>/dev/null; then
        echo "✓ Full compilation: SUCCESS"
        
        if [ -f "ng_shared_parallel_test" ]; then
            echo "✓ Executable created: ng_shared_parallel_test"
        else
            echo "✗ Executable not found after compilation"
        fi
    else
        echo "✗ Full compilation: FAILED (likely missing NGSpice library)"
        echo "  This is expected if NGSpice development packages are not installed"
    fi
    
    echo ""
}

# Function to show recommendations
show_recommendations() {
    echo "=========================================="
    echo "Recommendations:"
    echo "=========================================="
    
    local os=$(uname -s)
    
    case $os in
        Linux)
            echo "For Linux systems:"
            echo "  Ubuntu/Debian: sudo apt-get install ngspice libngspice0-dev"
            echo "  CentOS/RHEL:   sudo yum install ngspice ngspice-devel"
            echo "  Fedora:        sudo dnf install ngspice ngspice-devel"
            echo "  Arch:          sudo pacman -S ngspice"
            ;;
        Darwin)
            echo "For macOS systems:"
            echo "  MacPorts:      sudo port install ngspice +lib+manual"
            echo "  Homebrew:      brew install ngspice"
            ;;
        *)
            echo "For your system ($os):"
            echo "  Please install NGSpice and development libraries manually"
            ;;
    esac
    
    echo ""
    echo "After installing NGSpice, you can:"
    echo "  1. Run 'make config' to check configuration"
    echo "  2. Run 'make test' to build and test the program"
    echo "  3. Use './setup_linux.sh' for automated setup (Linux only)"
}

# Main execution
main() {
    check_system
    
    if ! check_tools; then
        echo "Please install missing tools and try again."
        exit 1
    fi
    
    check_ngspice
    test_basic_compilation
    test_project_compilation
    
    show_recommendations
    
    echo ""
    echo "=========================================="
    echo "Compilation test completed!"
    echo "=========================================="
}

# Run main function
main "$@"
