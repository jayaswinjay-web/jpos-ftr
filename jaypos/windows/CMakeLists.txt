cmake_minimum_required(VERSION 3.14)
project(jaypos LANGUAGES CXX)

set(BINARY_NAME "jaypos")
set(APPLICATION_ID "com.jaytech.jaypos")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

set(CMAKE_INSTALL_UCRT_LIBRARIES TRUE)

configure_file(
    windows/runner/CMakeLists.txt
    runner/CMakeLists.txt
)

add_subdirectory("runner")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")
