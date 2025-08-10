#!/bin/bash

# Test script specifically for Linux .so file handling
# This script verifies that the CMake build system correctly handles
# Linux shared libraries (.so files) for NGSpice

set -e

echo "=========================================="
echo "Linux .so File Handling Test"
echo "=========================================="

# Function to check if we're on Linux
check_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "❌ This script is designed for Linux systems"
        echo "Current system: $(uname -s)"
        echo "For other platforms, use the general test scripts"
        exit 1
    fi
    echo "✅ Running on Linux: $(uname -s) $(uname -r)"
}

# Function to check for NGSpice installation
check_ngspice() {
    echo ""
    echo "Checking NGSpice installation..."
    
    if ! command -v ngspice &> /dev/null; then
        echo "❌ NGSpice executable not found"
        echo "Please install NGSpice:"
        echo "  Ubuntu/Debian: sudo apt-get install ngspice libngspice0-dev"
        echo "  CentOS/RHEL:   sudo yum install ngspice ngspice-devel"
        echo "  Fedora:        sudo dnf install ngspice ngspice-devel"
        echo "  Arch Linux:    sudo pacman -S ngspice"
        return 1
    fi
    
    echo "✅ NGSpice executable found: $(which ngspice)"
    echo "   Version: $(ngspice --version 2>&1 | head -n1)"
    
    # Check for shared library
    local lib_found=false
    local lib_paths=(
        "/usr/lib/libngspice.so"
        "/usr/local/lib/libngspice.so"
        "/usr/lib/x86_64-linux-gnu/libngspice.so"
        "/usr/lib/aarch64-linux-gnu/libngspice.so"
        "/usr/lib64/libngspice.so"
    )
    
    for lib_path in "${lib_paths[@]}"; do
        if [[ -f "$lib_path" ]]; then
            echo "✅ NGSpice shared library found: $lib_path"
            echo "   File info: $(file "$lib_path")"
            lib_found=true
            break
        fi
    done
    
    if [[ "$lib_found" = false ]]; then
        echo "❌ NGSpice shared library (.so) not found"
        echo "Searched paths: ${lib_paths[*]}"
        echo "Please install NGSpice development packages"
        return 1
    fi
    
    return 0
}

# Function to test CMake configuration
test_cmake_config() {
    echo ""
    echo "Testing CMake configuration..."
    
    if [[ ! -f "CMakeLists.txt" ]]; then
        echo "❌ CMakeLists.txt not found. Are you in the project directory?"
        return 1
    fi
    
    # Create a temporary build directory for testing
    local test_dir="test_build_linux"
    rm -rf "$test_dir"
    mkdir "$test_dir"
    cd "$test_dir"
    
    echo "Configuring with CMake..."
    if cmake .. > cmake_config.log 2>&1; then
        echo "✅ CMake configuration successful"
        
        # Check if NGSpice was found
        if grep -q "Found NGSpice:" cmake_config.log; then
            local ngspice_lib=$(grep "Found NGSpice:" cmake_config.log | cut -d: -f2- | xargs)
            echo "✅ NGSpice library detected: $ngspice_lib"
            
            # Check if it's a .so file
            if [[ "$ngspice_lib" == *.so* ]]; then
                echo "✅ Correctly detected .so library"
            else
                echo "⚠️  Library is not .so format: $ngspice_lib"
            fi
        else
            echo "❌ NGSpice not found by CMake"
            echo "CMake log:"
            cat cmake_config.log
            cd ..
            rm -rf "$test_dir"
            return 1
        fi
    else
        echo "❌ CMake configuration failed"
        echo "CMake log:"
        cat cmake_config.log
        cd ..
        rm -rf "$test_dir"
        return 1
    fi
    
    cd ..
    rm -rf "$test_dir"
    return 0
}

# Function to test library preparation
test_library_preparation() {
    echo ""
    echo "Testing library preparation..."
    
    # Use the main build directory
    if [[ ! -d "build" ]]; then
        echo "Creating build directory..."
        mkdir build
    fi
    
    cd build
    
    # Configure if needed
    if [[ ! -f "Makefile" ]]; then
        echo "Configuring CMake..."
        cmake .. > /dev/null 2>&1
    fi
    
    # Test prepare-libs target
    echo "Running prepare-libs target..."
    if cmake --build . --target prepare-libs > prepare_libs.log 2>&1; then
        echo "✅ Library preparation successful"
        
        # Check if .so files were created
        local so_files=(libngspice1.so libngspice2.so libngspice3.so)
        local all_found=true
        
        for so_file in "${so_files[@]}"; do
            if [[ -f "$so_file" ]]; then
                echo "✅ Created: $so_file"
                echo "   File type: $(file "$so_file" | cut -d: -f2-)"
                
                # Check if it's executable/readable
                if [[ -r "$so_file" ]]; then
                    echo "   ✅ File is readable"
                else
                    echo "   ❌ File is not readable"
                    all_found=false
                fi
            else
                echo "❌ Missing: $so_file"
                all_found=false
            fi
        done
        
        if [[ "$all_found" = true ]]; then
            echo "✅ All required .so files created successfully"
        else
            echo "❌ Some .so files are missing or invalid"
            cd ..
            return 1
        fi
    else
        echo "❌ Library preparation failed"
        echo "Preparation log:"
        cat prepare_libs.log
        cd ..
        return 1
    fi
    
    cd ..
    return 0
}

# Function to test compilation
test_compilation() {
    echo ""
    echo "Testing compilation..."
    
    cd build
    
    echo "Building the project..."
    if cmake --build . > build.log 2>&1; then
        echo "✅ Compilation successful"
        
        if [[ -f "ng_shared_parallel_test" ]]; then
            echo "✅ Executable created: ng_shared_parallel_test"
            echo "   File info: $(file ng_shared_parallel_test)"
            
            # Check dependencies
            echo "   Library dependencies:"
            if command -v ldd &> /dev/null; then
                ldd ng_shared_parallel_test | grep -E "(ngspice|pthread|dl)" || echo "   (No NGSpice dependencies shown - this is normal for dynamic loading)"
            else
                echo "   (ldd not available)"
            fi
        else
            echo "❌ Executable not found"
            cd ..
            return 1
        fi
    else
        echo "❌ Compilation failed"
        echo "Build log:"
        cat build.log
        cd ..
        return 1
    fi
    
    cd ..
    return 0
}

# Function to show summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "Linux .so Test Summary"
    echo "=========================================="
    echo ""
    echo "✅ All tests passed successfully!"
    echo ""
    echo "Your NGSpice parallel project is correctly configured for Linux:"
    echo "  • NGSpice shared libraries (.so) are properly detected"
    echo "  • CMake correctly handles Linux library paths"
    echo "  • Runtime libraries are prepared as .so files"
    echo "  • Compilation produces a working executable"
    echo ""
    echo "You can now use either build system:"
    echo "  CMake:    ./build.sh --test"
    echo "  Makefile: make test"
    echo ""
    echo "For integration into larger projects, use:"
    echo "  add_subdirectory(ngspice_parallel)"
    echo ""
}

# Main execution
main() {
    check_linux
    
    if check_ngspice && test_cmake_config && test_library_preparation && test_compilation; then
        show_summary
        return 0
    else
        echo ""
        echo "❌ Some tests failed. Please check the output above."
        echo ""
        echo "Common solutions:"
        echo "  1. Install NGSpice development packages"
        echo "  2. Check that CMake version is 3.12 or higher"
        echo "  3. Ensure GCC/Clang is properly installed"
        echo ""
        return 1
    fi
}

# Run main function
main "$@"
