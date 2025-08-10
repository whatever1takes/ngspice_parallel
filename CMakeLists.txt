cmake_minimum_required(VERSION 3.12)
project(ngspice_parallel VERSION 1.0.0 LANGUAGES C)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Compiler-specific options
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra")
    set(CMAKE_C_FLAGS_DEBUG "-g -DDEBUG -O0")
    set(CMAKE_C_FLAGS_RELEASE "-O2 -DNDEBUG")
endif()

# Platform-specific definitions
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    add_definitions(-D_GNU_SOURCE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    add_definitions(-D_DARWIN_C_SOURCE)
endif()

# Add cmake modules path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Find required packages
find_package(Threads REQUIRED)

# Find dlopen library
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_library(DL_LIBRARY dl)
    if(NOT DL_LIBRARY)
        message(FATAL_ERROR "libdl not found")
    endif()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    # On macOS, dlopen is part of the system library
    set(DL_LIBRARY "")
endif()

# Find NGSpice using our custom module
find_package(NGSpice)

# Check if NGSpice was found
if(NGSpice_FOUND)
    message(STATUS "Found NGSpice: ${NGSpice_LIBRARIES}")
    message(STATUS "NGSpice include dir: ${NGSpice_INCLUDE_DIRS}")
    if(NGSpice_VERSION)
        message(STATUS "NGSpice version: ${NGSpice_VERSION}")
    endif()

    # Show library type for debugging
    get_filename_component(NGSpice_LIB_EXT "${NGSpice_LIBRARIES}" EXT)
    message(STATUS "NGSpice library extension: ${NGSpice_LIB_EXT}")
else()
    message(WARNING "NGSpice not found. The program will compile but may not link properly.")
    message(STATUS "Please install NGSpice development packages:")
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        message(STATUS "  Ubuntu/Debian: sudo apt-get install ngspice libngspice0-dev")
        message(STATUS "  CentOS/RHEL:   sudo yum install ngspice ngspice-devel")
        message(STATUS "  Fedora:        sudo dnf install ngspice ngspice-devel")
        message(STATUS "  Arch Linux:    sudo pacman -S ngspice")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        message(STATUS "  MacPorts:      sudo port install ngspice +lib+manual")
        message(STATUS "  Homebrew:      brew install ngspice")
    endif()
endif()

# Include directories
include_directories(include)
if(NGSpice_FOUND)
    include_directories(${NGSpice_INCLUDE_DIRS})
endif()

# Source files
set(SOURCES
    ng_shared_parallel/main.c
)

# Create executable
add_executable(ng_shared_parallel_test ${SOURCES})

# Link libraries
target_link_libraries(ng_shared_parallel_test
    Threads::Threads
    ${DL_LIBRARY}
)

if(NGSpice_FOUND)
    target_link_libraries(ng_shared_parallel_test NGSpice::NGSpice)
endif()

# Custom target to prepare runtime libraries
add_custom_target(prepare-libs
    COMMAND ${CMAKE_COMMAND} -E echo "Preparing shared libraries..."
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/cmake/PrepareLibs.cmake
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Copying NGSpice libraries for runtime"
)

# Custom target to run tests
add_custom_target(run-test
    COMMAND ${CMAKE_COMMAND} -E echo "Running NGSpice parallel test..."
    COMMAND $<TARGET_FILE:ng_shared_parallel_test>
    DEPENDS ng_shared_parallel_test prepare-libs
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running the NGSpice parallel test program"
)

# Install target
install(TARGETS ng_shared_parallel_test
    RUNTIME DESTINATION bin
    COMPONENT Runtime
)

# Install examples
install(DIRECTORY examples/
    DESTINATION share/ngspice_parallel/examples
    COMPONENT Examples
)

# Install documentation
install(FILES 
    README_Linux_macOS.md
    howto_start_sync.txt
    DESTINATION share/doc/ngspice_parallel
    COMPONENT Documentation
)

# CPack configuration for packaging
set(CPACK_PACKAGE_NAME "ngspice_parallel")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "NGSpice Parallel Simulation Test Program")
set(CPACK_PACKAGE_VENDOR "NGSpice Community")
set(CPACK_PACKAGE_CONTACT "community@ngspice.org")

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CPACK_GENERATOR "DEB;RPM;TGZ")
    set(CPACK_DEBIAN_PACKAGE_DEPENDS "ngspice, libngspice0")
    set(CPACK_RPM_PACKAGE_REQUIRES "ngspice, ngspice-devel")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(CPACK_GENERATOR "TGZ;ZIP")
endif()

include(CPack)

# Print configuration summary
message(STATUS "")
message(STATUS "=== NGSpice Parallel Build Configuration ===")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "C Flags: ${CMAKE_C_FLAGS}")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(STATUS "Debug Flags: ${CMAKE_C_FLAGS_DEBUG}")
else()
    message(STATUS "Release Flags: ${CMAKE_C_FLAGS_RELEASE}")
endif()
message(STATUS "System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "NGSpice Found: ${NGSpice_FOUND}")
if(NGSpice_FOUND)
    message(STATUS "NGSpice Library: ${NGSpice_LIBRARIES}")
    message(STATUS "NGSpice Include: ${NGSpice_INCLUDE_DIRS}")
    if(NGSpice_VERSION)
        message(STATUS "NGSpice Version: ${NGSpice_VERSION}")
    endif()
endif()
message(STATUS "Install Prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "===========================================")
message(STATUS "")

# Show available targets
message(STATUS "Available targets:")
message(STATUS "  ng_shared_parallel_test - Build the main executable")
message(STATUS "  prepare-libs           - Prepare runtime libraries")
message(STATUS "  run-test              - Build and run the test")
message(STATUS "  install               - Install the program")
message(STATUS "  package               - Create distribution package")
message(STATUS "")
