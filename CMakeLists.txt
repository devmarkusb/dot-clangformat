cmake_minimum_required(VERSION 3.14)
# Standalone project (optional); primary use is FetchContent + add_subdirectory.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(mb_dot_clang_format NONE)
endif()

option(MB_DOT_CLANG_FORMAT_ENABLE "Copy .clang-format from mb-dot-clang-format into the consumer project" ON)
option(MB_DOT_CLANG_FORMAT_QUIET "Suppress mb-dot-clang-format status messages" OFF)
set(MB_DOT_CLANG_FORMAT_OUTPUT "${CMAKE_SOURCE_DIR}/.clang-format" CACHE FILEPATH
  "Where to install .clang-format (defaults to consumer project root)")
set(MB_DOT_CLANG_FORMAT_CLANG_FORMAT_MAJOR "" CACHE STRING
  "clang-format major version (e.g. match pre-commit); empty = detect via clang-format in PATH")
set(MB_DOT_CLANG_FORMAT_FORCE_CONFIG_VERSION "" CACHE STRING
  "Use configs/vN/.clang-format (e.g. 14 or 22); empty = pick by clang-format major")

include("${CMAKE_CURRENT_LIST_DIR}/cmake/mb-dot-clang-format.cmake")
mb_dot_clang_format_install()
