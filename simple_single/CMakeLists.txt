cmake_minimum_required(VERSION 3.12)
project(ngspice_simple_single VERSION 1.0.0 LANGUAGES C)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Find NGSpice library
find_library(NGSPICE_LIBRARY
    NAMES ngspice
    PATHS
        /usr/lib
        /usr/local/lib
        /usr/lib/x86_64-linux-gnu
        /usr/lib64
        /opt/local/lib
    DOC "NGSpice library"
)

# Find NGSpice headers
find_path(NGSPICE_INCLUDE_DIR
    NAMES ngspice/sharedspice.h
    PATHS
        /usr/include
        /usr/local/include
        /opt/local/include
    DOC "NGSpice include directory"
)

# Check if NGSpice was found
if(NGSPICE_LIBRARY AND NGSPICE_INCLUDE_DIR)
    message(STATUS "Found NGSpice: ${NGSPICE_LIBRARY}")
    message(STATUS "NGSpice include: ${NGSPICE_INCLUDE_DIR}")
else()
    message(FATAL_ERROR "NGSpice not found!")
endif()

# Include directories
include_directories(${NGSPICE_INCLUDE_DIR})

# Create executable
add_executable(ngspice_simple_single main.c)

# Link libraries
target_link_libraries(ngspice_simple_single ${NGSPICE_LIBRARY})

# Show configuration
message(STATUS "")
message(STATUS "=== Simple Single Thread NGSpice ===")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "NGSpice found: ${NGSPICE_LIBRARY}")
message(STATUS "====================================")
message(STATUS "")
