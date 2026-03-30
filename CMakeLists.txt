# Standalone project (optional); primary use is FetchContent + add_subdirectory.
cmake_minimum_required(VERSION 3.14)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(mb_dot_clang_format NONE)
endif()

include("${CMAKE_CURRENT_LIST_DIR}/cmake/mb-dot-clang-format.cmake")
include(FetchContent)

FetchContent_Declare(
    mb_pre_commit
    GIT_REPOSITORY https://github.com/devmarkusb/pre-commit.git
    GIT_TAG v1.4.0
)
FetchContent_MakeAvailable(mb_pre_commit)
mb_pre_commit_setup()
