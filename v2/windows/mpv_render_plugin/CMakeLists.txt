cmake_minimum_required(VERSION 3.14)
project(mpv_render_plugin LANGUAGES CXX)

set(PLUGIN_NAME "mpv_render_plugin")

# ANGLE paths (precompiled binaries in windows/angle/)
set(ANGLE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../angle")
set(ANGLE_INCLUDE_DIR "${ANGLE_DIR}/include")
set(ANGLE_LIB_DIR "${ANGLE_DIR}/lib")

# mpv headers and library
set(MPV_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../libmpv")
set(MPV_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../libmpv")

add_library(${PLUGIN_NAME} SHARED "mpv_render_plugin.cpp")
apply_standard_settings(${PLUGIN_NAME})

target_include_directories(${PLUGIN_NAME} PRIVATE
  "${ANGLE_INCLUDE_DIR}" "${MPV_INCLUDE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral/cpp_client_wrapper/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../flutter/ephemeral"
)

# Link against ANGLE, D3D11, mpv, and Flutter wrapper plugin
target_link_libraries(${PLUGIN_NAME} PRIVATE
  "${ANGLE_LIB_DIR}/libEGL.lib"
  "${ANGLE_LIB_DIR}/libGLESv2.lib"
  "${MPV_LIB_DIR}/libmpv-2.lib"
  d3d11.lib dxgi.lib
  flutter_wrapper_plugin
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE "FLUTTER_PLUGIN_IMPL")

# UTF-8 encoding for Chinese comments
target_compile_options(${PLUGIN_NAME} PRIVATE "/utf-8")

# No PARENT_SCOPE here — ANGLE DLLs are copied via runner CMakeLists POST_BUILD
