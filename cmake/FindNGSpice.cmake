# FindNGSpice.cmake
# 
# Finds the NGSpice library and headers
#
# This will define the following variables:
#   NGSpice_FOUND         - True if NGSpice is found
#   NGSpice_INCLUDE_DIRS  - Include directories for NGSpice
#   NGSpice_LIBRARIES     - Libraries to link against NGSpice
#   NGSpice_VERSION       - Version of NGSpice (if available)
#
# and the following imported targets:
#   NGSpice::NGSpice      - The NGSpice library

# Find the header file
find_path(NGSpice_INCLUDE_DIR
    NAMES ngspice/sharedspice.h
    PATHS
        /usr/include
        /usr/local/include
        /opt/local/include
        /opt/homebrew/include
        ${NGSpice_ROOT}/include
        $ENV{NGSpice_ROOT}/include
    DOC "NGSpice include directory"
)

# Find the library
find_library(NGSpice_LIBRARY
    NAMES ngspice
    PATHS
        # Linux paths
        /usr/lib
        /usr/local/lib
        /usr/lib/x86_64-linux-gnu
        /usr/lib/aarch64-linux-gnu
        /usr/lib/arm-linux-gnueabihf
        /usr/lib64
        # macOS paths
        /opt/local/lib
        /opt/homebrew/lib
        # Custom paths
        ${NGSpice_ROOT}/lib
        $ENV{NGSpice_ROOT}/lib
    DOC "NGSpice library"
)

# Try to find the version
if(NGSpice_INCLUDE_DIR)
    set(NGSpice_VERSION_FILE "${NGSpice_INCLUDE_DIR}/ngspice/config.h")
    if(EXISTS "${NGSpice_VERSION_FILE}")
        file(STRINGS "${NGSpice_VERSION_FILE}" NGSpice_VERSION_LINE
            REGEX "^#define[ \t]+VERSION[ \t]+\"[^\"]*\"")
        if(NGSpice_VERSION_LINE)
            string(REGEX REPLACE "^#define[ \t]+VERSION[ \t]+\"([^\"]*)\".*" "\\1"
                NGSpice_VERSION "${NGSpice_VERSION_LINE}")
        endif()
    endif()
    
    # Alternative version detection
    if(NOT NGSpice_VERSION)
        set(NGSpice_VERSION_FILE "${NGSpice_INCLUDE_DIR}/ngspice/ngspice.h")
        if(EXISTS "${NGSpice_VERSION_FILE}")
            file(STRINGS "${NGSpice_VERSION_FILE}" NGSpice_VERSION_LINES
                REGEX "^#define[ \t]+NGSPICE_VERSION")
            foreach(line ${NGSpice_VERSION_LINES})
                if(line MATCHES "^#define[ \t]+NGSPICE_VERSION[ \t]+\"([^\"]*)\"")
                    set(NGSpice_VERSION "${CMAKE_MATCH_1}")
                    break()
                endif()
            endforeach()
        endif()
    endif()
endif()

# Handle standard arguments
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(NGSpice
    FOUND_VAR NGSpice_FOUND
    REQUIRED_VARS NGSpice_LIBRARY NGSpice_INCLUDE_DIR
    VERSION_VAR NGSpice_VERSION
)

# Set the output variables
if(NGSpice_FOUND)
    set(NGSpice_LIBRARIES ${NGSpice_LIBRARY})
    set(NGSpice_INCLUDE_DIRS ${NGSpice_INCLUDE_DIR})
    
    # Create imported target
    if(NOT TARGET NGSpice::NGSpice)
        add_library(NGSpice::NGSpice UNKNOWN IMPORTED)
        set_target_properties(NGSpice::NGSpice PROPERTIES
            IMPORTED_LOCATION "${NGSpice_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${NGSpice_INCLUDE_DIR}"
        )
    endif()
endif()

# Mark variables as advanced
mark_as_advanced(
    NGSpice_INCLUDE_DIR
    NGSpice_LIBRARY
)
