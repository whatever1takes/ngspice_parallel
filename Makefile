# Makefile for ngspice parallel test program
# Supports Linux and macOS compilation

# Compiler
CC = gcc

# Program name
PROGRAM = ng_shared_parallel_test

# Source files
SRCDIR = ng_shared_parallel
INCDIR = include
SOURCES = $(SRCDIR)/main.c

# Object files
OBJECTS = $(SOURCES:.c=.o)

# Detect operating system
UNAME_S := $(shell uname -s)

# Common compiler flags
CFLAGS = -Wall -Wextra -std=c99 -I$(INCDIR)

# Platform-specific settings
ifeq ($(UNAME_S),Linux)
    # Linux settings
    CFLAGS += -D_GNU_SOURCE
    LDFLAGS = -ldl -lpthread
    # Try to find ngspice library
    ifneq ($(wildcard /usr/local/lib/libngspice.so),)
        LDFLAGS += -L/usr/local/lib -lngspice
        CFLAGS += -I/usr/local/include
    else ifneq ($(wildcard /usr/lib/libngspice.so),)
        LDFLAGS += -L/usr/lib -lngspice
        CFLAGS += -I/usr/include
    else ifneq ($(wildcard /usr/lib/x86_64-linux-gnu/libngspice.so),)
        LDFLAGS += -L/usr/lib/x86_64-linux-gnu -lngspice
        CFLAGS += -I/usr/include
    endif
endif

ifeq ($(UNAME_S),Darwin)
    # macOS settings
    CFLAGS += -D_DARWIN_C_SOURCE
    LDFLAGS = -ldl -lpthread
    # Check for MacPorts installation
    ifneq ($(wildcard /opt/local/lib/libngspice.dylib),)
        LDFLAGS += -L/opt/local/lib -lngspice
        CFLAGS += -I/opt/local/include
    # Check for Homebrew installation
    else ifneq ($(wildcard /usr/local/lib/libngspice.dylib),)
        LDFLAGS += -L/usr/local/lib -lngspice
        CFLAGS += -I/usr/local/include
    # Check for Homebrew on Apple Silicon
    else ifneq ($(wildcard /opt/homebrew/lib/libngspice.dylib),)
        LDFLAGS += -L/opt/homebrew/lib -lngspice
        CFLAGS += -I/opt/homebrew/include
    endif
endif

# Debug and release targets
DEBUG_CFLAGS = $(CFLAGS) -g -DDEBUG -O0
RELEASE_CFLAGS = $(CFLAGS) -O2 -DNDEBUG

# Default target
all: release

# Debug build
debug: CFLAGS := $(DEBUG_CFLAGS)
debug: $(PROGRAM)

# Release build
release: CFLAGS := $(RELEASE_CFLAGS)
release: $(PROGRAM)

# Main target
$(PROGRAM): $(OBJECTS)
	$(CC) $(OBJECTS) -o $@ $(LDFLAGS)

# Compile source files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Clean build files
clean:
	rm -f $(OBJECTS) $(PROGRAM)
	rm -f *.raw *.out

# Install target (optional)
install: $(PROGRAM)
	install -m 755 $(PROGRAM) /usr/local/bin/

# Uninstall target (optional)
uninstall:
	rm -f /usr/local/bin/$(PROGRAM)

# Create necessary shared libraries for testing (Linux/macOS specific)
prepare-libs:
ifeq ($(UNAME_S),Linux)
	@echo "Preparing shared libraries for Linux..."
	@if [ -f /usr/local/lib/libngspice.so ]; then \
		cp /usr/local/lib/libngspice.so ./libngspice1.so; \
		cp /usr/local/lib/libngspice.so ./libngspice2.so; \
		cp /usr/local/lib/libngspice.so ./libngspice3.so; \
	elif [ -f /usr/lib/libngspice.so ]; then \
		cp /usr/lib/libngspice.so ./libngspice1.so; \
		cp /usr/lib/libngspice.so ./libngspice2.so; \
		cp /usr/lib/libngspice.so ./libngspice3.so; \
	elif [ -f /usr/lib/x86_64-linux-gnu/libngspice.so ]; then \
		cp /usr/lib/x86_64-linux-gnu/libngspice.so ./libngspice1.so; \
		cp /usr/lib/x86_64-linux-gnu/libngspice.so ./libngspice2.so; \
		cp /usr/lib/x86_64-linux-gnu/libngspice.so ./libngspice3.so; \
	else \
		echo "Error: libngspice.so not found. Please install ngspice development package."; \
		exit 1; \
	fi
endif
ifeq ($(UNAME_S),Darwin)
	@echo "Preparing shared libraries for macOS..."
	@if [ -f /opt/local/lib/libngspice.dylib ]; then \
		cp /opt/local/lib/libngspice.dylib ./libngspice1.so; \
		cp /opt/local/lib/libngspice.dylib ./libngspice2.so; \
		cp /opt/local/lib/libngspice.dylib ./libngspice3.so; \
	elif [ -f /usr/local/lib/libngspice.dylib ]; then \
		cp /usr/local/lib/libngspice.dylib ./libngspice1.so; \
		cp /usr/local/lib/libngspice.dylib ./libngspice2.so; \
		cp /usr/local/lib/libngspice.dylib ./libngspice3.so; \
	elif [ -f /opt/homebrew/lib/libngspice.dylib ]; then \
		cp /opt/homebrew/lib/libngspice.dylib ./libngspice1.so; \
		cp /opt/homebrew/lib/libngspice.dylib ./libngspice2.so; \
		cp /opt/homebrew/lib/libngspice.dylib ./libngspice3.so; \
	else \
		echo "Error: libngspice.dylib not found. Please install ngspice."; \
		exit 1; \
	fi
endif

# Test target
test: $(PROGRAM) prepare-libs
	./$(PROGRAM)

# Show build configuration
config:
	@echo "Build configuration:"
	@echo "OS: $(UNAME_S)"
	@echo "CC: $(CC)"
	@echo "CFLAGS: $(CFLAGS)"
	@echo "LDFLAGS: $(LDFLAGS)"

# Help target
help:
	@echo "Available targets:"
	@echo "  all         - Build release version (default)"
	@echo "  debug       - Build debug version"
	@echo "  release     - Build release version"
	@echo "  clean       - Remove build files"
	@echo "  prepare-libs- Copy ngspice libraries for testing"
	@echo "  test        - Build and run the program"
	@echo "  config      - Show build configuration"
	@echo "  install     - Install to /usr/local/bin"
	@echo "  uninstall   - Remove from /usr/local/bin"
	@echo "  help        - Show this help"

.PHONY: all debug release clean install uninstall prepare-libs test config help
