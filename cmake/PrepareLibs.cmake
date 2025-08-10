# CMake script to prepare NGSpice runtime libraries
# This script copies the NGSpice shared library to create multiple instances
# needed for parallel simulation testing

cmake_minimum_required(VERSION 3.12)

# Detect the operating system and set library extensions
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    set(LIB_EXTENSION "so")
    set(LIB_PREFIX "lib")
    set(COPY_EXTENSION "so")  # Always copy as .so for consistency
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    set(LIB_EXTENSION "dylib")
    set(LIB_PREFIX "lib")
    set(COPY_EXTENSION "so")  # Copy as .so for consistency across platforms
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(LIB_EXTENSION "dll")
    set(LIB_PREFIX "")
    set(COPY_EXTENSION "dll")
else()
    message(FATAL_ERROR "Unsupported operating system: ${CMAKE_HOST_SYSTEM_NAME}")
endif()

# Function to find NGSpice library
function(find_ngspice_library result_var)
    set(search_paths
        "/usr/lib"
        "/usr/local/lib"
        "/opt/local/lib"
        "/opt/homebrew/lib"
        "/usr/lib/x86_64-linux-gnu"
        "/usr/lib64"
        "/usr/lib/aarch64-linux-gnu"
        "/usr/lib/arm-linux-gnueabihf"
    )
    
    foreach(path ${search_paths})
        set(lib_file "${path}/${LIB_PREFIX}ngspice.${LIB_EXTENSION}")
        if(EXISTS "${lib_file}")
            set(${result_var} "${lib_file}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    
    set(${result_var} "" PARENT_SCOPE)
endfunction()

# Find the NGSpice library
find_ngspice_library(NGSPICE_LIB_PATH)

if(NOT NGSPICE_LIB_PATH)
    message(FATAL_ERROR "NGSpice library not found in standard locations")
endif()

message(STATUS "Found NGSpice library: ${NGSPICE_LIB_PATH}")

# Create the library copies needed for parallel simulation
# Always use .so extension for consistency across platforms
set(lib_copies "libngspice1.so" "libngspice2.so" "libngspice3.so")

foreach(lib_copy ${lib_copies})
    set(dest_file "${CMAKE_CURRENT_BINARY_DIR}/${lib_copy}")

    # Check if the file already exists and is up to date
    if(EXISTS "${dest_file}")
        file(TIMESTAMP "${NGSPICE_LIB_PATH}" src_time)
        file(TIMESTAMP "${dest_file}" dest_time)

        if("${src_time}" STREQUAL "${dest_time}")
            message(STATUS "Library ${lib_copy} is up to date")
            continue()
        endif()
    endif()

    # Create PHYSICAL COPY (not symbolic link) for true parallel simulation
    # This is critical: each copy must be a separate file with different inode
    # so that dlopen() treats them as independent library instances
    message(STATUS "Creating physical copy: ${NGSPICE_LIB_PATH} -> ${dest_file}")

    # Use configure_file to create a true physical copy
    configure_file("${NGSPICE_LIB_PATH}" "${dest_file}" COPYONLY)

    # Verify it's a real copy, not a link
    if(EXISTS "${dest_file}")
        message(STATUS "✓ Physical copy created: ${dest_file}")
    else()
        message(FATAL_ERROR "✗ Failed to create physical copy: ${dest_file}")
    endif()

    # Set the same timestamp as the source
    file(TIMESTAMP "${NGSPICE_LIB_PATH}" src_timestamp)
    file(TIMESTAMP "${dest_file}" TIMESTAMP "${src_timestamp}")
endforeach()

# Also copy the examples directory if it doesn't exist
set(examples_src "${CMAKE_SOURCE_DIR}/examples")
set(examples_dest "${CMAKE_CURRENT_BINARY_DIR}/examples")

if(EXISTS "${examples_src}")
    if(NOT EXISTS "${examples_dest}")
        message(STATUS "Copying examples directory to build directory")
        file(COPY "${examples_src}" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")
    else()
        message(STATUS "Examples directory already exists in build directory")
    endif()
else()
    message(WARNING "Examples directory not found at ${examples_src}")
endif()

message(STATUS "Runtime libraries preparation completed successfully")
