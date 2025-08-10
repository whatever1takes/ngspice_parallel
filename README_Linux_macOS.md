# NGSpice Parallel Test Program - Linux/macOS Support

This project demonstrates parallel ngspice simulation with synchronization support. Originally designed for Windows/Visual Studio, this version has been adapted to work on Linux and macOS systems.

## Overview

The program loads multiple ngspice shared library instances and runs synchronized parallel simulations. It includes two test scenarios:

1. **Test 1**: Load two ngspice instances and run independent simulations
2. **Test 2**: Load three ngspice instances and run synchronized simulations with circuit partitioning

## Prerequisites

### System Requirements
- Linux or macOS operating system
- GCC compiler with C99 support
- NGSpice development libraries
- POSIX threads support (pthread)
- Dynamic library loading support (libdl)

### Installing NGSpice

#### On Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install ngspice libngspice0-dev
```

#### On CentOS/RHEL/Fedora:
```bash
# CentOS/RHEL
sudo yum install ngspice ngspice-devel
# or Fedora
sudo dnf install ngspice ngspice-devel
```

#### On macOS with MacPorts:
```bash
sudo port install ngspice +lib+manual
```

#### On macOS with Homebrew:
```bash
brew install ngspice
```

## Building the Project

### Using the Provided Makefile

1. **Check build configuration:**
   ```bash
   make config
   ```

2. **Build debug version:**
   ```bash
   make debug
   ```

3. **Build release version:**
   ```bash
   make release
   # or simply
   make
   ```

4. **Clean build files:**
   ```bash
   make clean
   ```

### Manual Compilation

If you prefer to compile manually:

```bash
# For Linux
gcc -Wall -Wextra -std=c99 -Iinclude -D_GNU_SOURCE \
    -I/usr/include -I/usr/local/include \
    ng_shared_parallel/main.c \
    -o ng_shared_parallel_test \
    -ldl -lpthread -lngspice

# For macOS
gcc -Wall -Wextra -std=c99 -Iinclude -D_DARWIN_C_SOURCE \
    -I/opt/local/include \
    ng_shared_parallel/main.c \
    -o ng_shared_parallel_test \
    -ldl -lpthread -L/opt/local/lib -lngspice
```

## Running the Program

### Prepare Runtime Libraries

Before running, you need to create copies of the ngspice shared library:

```bash
make prepare-libs
```

This will create `libngspice1.so`, `libngspice2.so`, and `libngspice3.so` files needed for the parallel simulation.

### Execute the Test

```bash
./ng_shared_parallel_test
```

Or use the convenient test target:

```bash
make test
```

## Expected Output

The program will:

1. Load three ngspice library instances
2. Initialize each with callback functions
3. Load circuit files from the `examples/` directory
4. Run synchronized parallel simulations
5. Generate raw data files (`nsynctest1.raw`, `nsynctest2.raw`, `nsynctest3.raw`)
6. Display performance statistics

## Project Structure

```
ngspice_parallel/
├── Makefile                    # Build configuration for Linux/macOS
├── README_Linux_macOS.md       # This file
├── howto_start_sync.txt        # Original Windows instructions
├── include/
│   └── sharedspice.h          # NGSpice shared library interface
├── ng_shared_parallel/
│   └── main.c                 # Main test program
├── ng_shared_parallel_v/       # Visual Studio project files
└── examples/                   # Test circuit files
    ├── adder_mos.cir
    ├── inv_oc1.cir
    ├── inv_oc2.cir
    ├── inv_oc3.cir
    ├── modelcard.nmos
    └── modelcard.pmos
```

## Makefile Targets

- `all` / `release`: Build optimized release version
- `debug`: Build debug version with symbols
- `clean`: Remove build artifacts
- `prepare-libs`: Copy ngspice libraries for runtime
- `test`: Build and run the program
- `config`: Show build configuration
- `install`: Install to `/usr/local/bin`
- `uninstall`: Remove from `/usr/local/bin`
- `help`: Show available targets

## Troubleshooting

### Library Not Found
If you get "library not found" errors:

1. Check if ngspice is installed: `ngspice --version`
2. Verify library location: `find /usr -name "*ngspice*" 2>/dev/null`
3. Update the Makefile paths if needed

### Compilation Warnings
The program may generate warnings about:
- Unused variables/parameters (safe to ignore)
- Format string security (safe to ignore for this test program)
- Undefined behavior with bit shifts (legacy code issue)

### Runtime Issues
- Ensure all three `libngspice*.so` files exist in the working directory
- Check that circuit files exist in the `examples/` directory
- Verify ngspice library compatibility

## Platform-Specific Notes

### Linux
- Tested on Ubuntu 20.04+ and CentOS 8+
- Uses GNU C Library extensions
- Requires pthread and dl libraries

### macOS
- Tested on macOS 10.15+ (both Intel and Apple Silicon)
- Works with both MacPorts and Homebrew installations
- Uses Darwin-specific C library extensions

## Performance Notes

The synchronized parallel simulation demonstrates:
- Multi-threaded ngspice execution
- Inter-thread synchronization mechanisms
- Circuit partitioning techniques
- Performance monitoring capabilities

Typical performance shows near-linear scaling with the number of parallel instances, limited by synchronization overhead.

## License

This code is based on the original work by Holger Vogt (2013) and maintains the same licensing terms. The Linux/macOS adaptations are provided under the same license.
