#!/bin/bash

# NGSpice Parallel Test Setup Script for Linux
# This script automates the installation and compilation process

set -e  # Exit on any error

echo "=========================================="
echo "NGSpice Parallel Test Setup for Linux"
echo "=========================================="

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Function to install dependencies
install_dependencies() {
    local distro=$(detect_distro)
    echo "Detected distribution: $distro"
    
    case $distro in
        ubuntu|debian)
            echo "Installing dependencies for Ubuntu/Debian..."
            sudo apt-get update
            sudo apt-get install -y build-essential gcc libc6-dev
            sudo apt-get install -y ngspice libngspice0-dev
            ;;
        fedora)
            echo "Installing dependencies for Fedora..."
            sudo dnf install -y gcc glibc-devel make
            sudo dnf install -y ngspice ngspice-devel
            ;;
        centos|rhel)
            echo "Installing dependencies for CentOS/RHEL..."
            sudo yum install -y gcc glibc-devel make
            sudo yum install -y ngspice ngspice-devel
            ;;
        arch)
            echo "Installing dependencies for Arch Linux..."
            sudo pacman -S --needed gcc glibc make
            sudo pacman -S --needed ngspice
            ;;
        opensuse*)
            echo "Installing dependencies for openSUSE..."
            sudo zypper install -y gcc glibc-devel make
            sudo zypper install -y ngspice ngspice-devel
            ;;
        *)
            echo "Unknown distribution. Please install the following manually:"
            echo "- GCC compiler and development tools"
            echo "- NGSpice and NGSpice development libraries"
            echo "- pthread and dl libraries (usually included with glibc)"
            return 1
            ;;
    esac
}

# Function to verify installation
verify_installation() {
    echo "Verifying installation..."
    
    # Check GCC
    if ! command -v gcc &> /dev/null; then
        echo "ERROR: GCC not found"
        return 1
    fi
    echo "✓ GCC found: $(gcc --version | head -n1)"
    
    # Check NGSpice
    if ! command -v ngspice &> /dev/null; then
        echo "ERROR: NGSpice not found"
        return 1
    fi
    echo "✓ NGSpice found: $(ngspice --version 2>&1 | head -n1)"
    
    # Check for NGSpice library
    local lib_found=false
    for lib_path in /usr/lib /usr/local/lib /usr/lib/x86_64-linux-gnu /usr/lib64; do
        if [ -f "$lib_path/libngspice.so" ]; then
            echo "✓ NGSpice library found: $lib_path/libngspice.so"
            lib_found=true
            break
        fi
    done
    
    if [ "$lib_found" = false ]; then
        echo "WARNING: NGSpice shared library not found in standard locations"
        echo "You may need to install ngspice development packages"
    fi
}

# Function to build the project
build_project() {
    echo "Building the project..."
    
    if [ ! -f "Makefile" ]; then
        echo "ERROR: Makefile not found. Are you in the correct directory?"
        return 1
    fi
    
    # Show configuration
    make config
    
    # Clean and build
    make clean
    make release
    
    echo "✓ Build completed successfully"
}

# Function to prepare runtime environment
prepare_runtime() {
    echo "Preparing runtime environment..."
    
    # Create library copies
    make prepare-libs
    
    echo "✓ Runtime libraries prepared"
}

# Function to run tests
run_tests() {
    echo "Running tests..."
    
    if [ ! -f "./ng_shared_parallel_test" ]; then
        echo "ERROR: Executable not found"
        return 1
    fi
    
    # Run the test
    echo "Starting NGSpice parallel test..."
    ./ng_shared_parallel_test
    
    # Check for output files
    if [ -f "nsynctest1.raw" ] && [ -f "nsynctest2.raw" ] && [ -f "nsynctest3.raw" ]; then
        echo "✓ Test completed successfully - output files generated"
        ls -la *.raw
    else
        echo "WARNING: Some output files may be missing"
    fi
}

# Main execution
main() {
    echo "Starting setup process..."
    
    # Check if running as root (not recommended)
    if [ "$EUID" -eq 0 ]; then
        echo "WARNING: Running as root is not recommended"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Parse command line arguments
    INSTALL_DEPS=true
    BUILD_PROJECT=true
    RUN_TESTS=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-install)
                INSTALL_DEPS=false
                shift
                ;;
            --no-build)
                BUILD_PROJECT=false
                shift
                ;;
            --no-test)
                RUN_TESTS=false
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --no-install    Skip dependency installation"
                echo "  --no-build      Skip building the project"
                echo "  --no-test       Skip running tests"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Execute steps
    if [ "$INSTALL_DEPS" = true ]; then
        install_dependencies
    fi
    
    verify_installation
    
    if [ "$BUILD_PROJECT" = true ]; then
        build_project
        prepare_runtime
    fi
    
    if [ "$RUN_TESTS" = true ]; then
        run_tests
    fi
    
    echo ""
    echo "=========================================="
    echo "Setup completed successfully!"
    echo "=========================================="
    echo ""
    echo "You can now run the program with:"
    echo "  ./ng_shared_parallel_test"
    echo ""
    echo "Or use the Makefile targets:"
    echo "  make test      # Build and run tests"
    echo "  make clean     # Clean build files"
    echo "  make help      # Show all available targets"
}

# Run main function with all arguments
main "$@"
