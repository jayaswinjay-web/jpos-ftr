cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(BINARY_NAME "jaypos")
set(APPLICATION_ID "com.jaytech.jaypos")

# Flutter embedder
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../flutter")

# Windows desktop application
add_executable(${BINARY_NAME}
    "main.cpp"
    "utils.cpp"
    "flutter_window.cpp"
    "flutter_windows.cpp"
    "win32_window.cpp"
)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

target_link_libraries(${BINARY_NAME} PRIVATE "flutter_wrapper" "dwmapi")

add_dependencies(${BINARY_NAME} flutter_assemble)

include_directories("${FLUTTER_MANAGED_DIR}/ephemeral/windows")

set(FLUTTER_LIBRARY "${FLUTTER_MANAGED_DIR}/ephemeral/windows/flutter_wrapper.dll.lib")

target_compile_definitions(${BINARY_NAME} PRIVATE "$<$<CONFIG:Debug>:FLUTTER_DEBUG>")

set(APPLICATION_ID "com.jaytech.jaypos")
