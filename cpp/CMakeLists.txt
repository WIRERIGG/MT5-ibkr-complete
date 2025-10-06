cmake_minimum_required(VERSION 3.10)
project(AutoFibIBKR)

# Set C++ standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# IBKR API paths
set(IBKR_API_DIR "${CMAKE_SOURCE_DIR}/IBJts/source/cppclient")
set(IBKR_CLIENT_DIR "${IBKR_API_DIR}/client")

# Include directories
include_directories(
    ${CMAKE_SOURCE_DIR}
    ${IBKR_CLIENT_DIR}
)

# IBKR API source files (exclude Decimal.cpp as it requires Intel BID library)
file(GLOB IBKR_SOURCES
    "${IBKR_CLIENT_DIR}/*.cpp"
)
list(REMOVE_ITEM IBKR_SOURCES "${IBKR_CLIENT_DIR}/Decimal.cpp")

# Our source files
set(AUTOFIB_SOURCES
    AutoFibIndicator.cpp
    IBKRAutoFibClient.cpp
    main.cpp
    DecimalStub.cpp
)

# Create executable
add_executable(autofib_ibkr
    ${AUTOFIB_SOURCES}
    ${IBKR_SOURCES}
)

# Link pthread (required for threading)
target_link_libraries(autofib_ibkr pthread)

# Compiler warnings
if(CMAKE_COMPILER_IS_GNUCXX)
    target_compile_options(autofib_ibkr PRIVATE -Wall -Wextra -Wno-unused-parameter)
endif()

# Output directory
set_target_properties(autofib_ibkr PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

# Print configuration
message(STATUS "==============================================")
message(STATUS "Auto Fibonacci IBKR C++ Configuration")
message(STATUS "==============================================")
message(STATUS "C++ Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "IBKR API Dir: ${IBKR_API_DIR}")
message(STATUS "==============================================")
