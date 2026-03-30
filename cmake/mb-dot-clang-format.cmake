# mb-dot-clang-format — copy the best matching configs/vN/.clang-format into the consumer tree.
# Logic lives in python/mb-dot-clang-format.py (also runnable without CMake). See README.md.
#
# CMAKE_SOURCE_DIR must be the consumer project root (true when this file is included
# from a dependency added with FetchContent_MakeAvailable).

get_filename_component(
    _MB_DOT_CLANG_FORMAT_REPO_ROOT
    "${CMAKE_CURRENT_LIST_DIR}/.."
    ABSOLUTE
)

# When this repo is the top-level project, default OFF so configure does not write ./.clang-format
# here; when embedded via add_subdirectory/FetchContent, CMAKE_SOURCE_DIR is the consumer root —
# default ON for those projects.
if(_MB_DOT_CLANG_FORMAT_REPO_ROOT STREQUAL CMAKE_SOURCE_DIR)
    set(_MB_DOT_CLANG_FORMAT_DEFAULT_ENABLE OFF)
else()
    set(_MB_DOT_CLANG_FORMAT_DEFAULT_ENABLE ON)
endif()

option(
    MB_DOT_CLANG_FORMAT_ENABLE
    "Copy .clang-format from mb-dot-clang-format into the consumer project"
    ${_MB_DOT_CLANG_FORMAT_DEFAULT_ENABLE}
)
option(
    MB_DOT_CLANG_FORMAT_QUIET
    "Suppress mb-dot-clang-format status messages"
    OFF
)
option(
    MB_DOT_CLANG_FORMAT_NO_AUTO_INSTALL
    "If ON, only define mb_dot_clang_format_install(); do not run it when this file is included"
    OFF
)
set(MB_DOT_CLANG_FORMAT_OUTPUT
    "${CMAKE_SOURCE_DIR}/.clang-format"
    CACHE FILEPATH
    "Where to install .clang-format (defaults to consumer project root)"
)
set(MB_DOT_CLANG_FORMAT_CLANG_FORMAT_MAJOR
    ""
    CACHE STRING
    "clang-format major version (e.g. match pre-commit); empty = detect via clang-format in PATH"
)
set(MB_DOT_CLANG_FORMAT_FORCE_CONFIG_VERSION
    ""
    CACHE STRING
    "Use configs/vN/.clang-format (e.g. 14 or 22); empty = pick by clang-format major"
)

function(mb_dot_clang_format_install)
    if(NOT MB_DOT_CLANG_FORMAT_ENABLE)
        message(
            STATUS
            "mb-dot-clang-format: disabled (MB_DOT_CLANG_FORMAT_ENABLE=OFF)"
        )
        return()
    endif()

    find_package(Python3 COMPONENTS Interpreter REQUIRED)

    set(_script
        "${_MB_DOT_CLANG_FORMAT_REPO_ROOT}/python/mb-dot-clang-format.py"
    )
    if(NOT EXISTS "${_script}")
        message(FATAL_ERROR "mb-dot-clang-format: missing ${_script}")
    endif()

    if(
        NOT DEFINED MB_DOT_CLANG_FORMAT_OUTPUT
        OR "${MB_DOT_CLANG_FORMAT_OUTPUT}" STREQUAL ""
    )
        set(MB_DOT_CLANG_FORMAT_OUTPUT "${CMAKE_SOURCE_DIR}/.clang-format")
    endif()

    set(_py_cmd
        "${Python3_EXECUTABLE}"
        "${_script}"
        --repo-root
        "${_MB_DOT_CLANG_FORMAT_REPO_ROOT}"
        --output
        "${MB_DOT_CLANG_FORMAT_OUTPUT}"
    )

    if(
        MB_DOT_CLANG_FORMAT_FORCE_CONFIG_VERSION
        AND NOT "${MB_DOT_CLANG_FORMAT_FORCE_CONFIG_VERSION}" STREQUAL ""
    )
        list(
            APPEND _py_cmd
            --force-config-version
            "${MB_DOT_CLANG_FORMAT_FORCE_CONFIG_VERSION}"
        )
    elseif(NOT "${MB_DOT_CLANG_FORMAT_CLANG_FORMAT_MAJOR}" STREQUAL "")
        list(
            APPEND _py_cmd
            --clang-format-major
            "${MB_DOT_CLANG_FORMAT_CLANG_FORMAT_MAJOR}"
        )
    endif()

    if(MB_DOT_CLANG_FORMAT_QUIET)
        list(APPEND _py_cmd --quiet)
    endif()

    execute_process(
        COMMAND ${_py_cmd}
        RESULT_VARIABLE _MB_DOT_CLANG_FORMAT_RC
        OUTPUT_VARIABLE _MB_DOT_CLANG_FORMAT_OUT
        ERROR_VARIABLE _MB_DOT_CLANG_FORMAT_ERR
    )
    if(NOT _MB_DOT_CLANG_FORMAT_RC EQUAL 0)
        message(
            FATAL_ERROR
            "mb-dot-clang-format:\n${_MB_DOT_CLANG_FORMAT_ERR}${_MB_DOT_CLANG_FORMAT_OUT}"
        )
    endif()
    if(NOT MB_DOT_CLANG_FORMAT_QUIET AND _MB_DOT_CLANG_FORMAT_OUT)
        string(STRIP "${_MB_DOT_CLANG_FORMAT_OUT}" _MB_DOT_CLANG_FORMAT_OUT)
        message(STATUS "${_MB_DOT_CLANG_FORMAT_OUT}")
    endif()
endfunction()

get_property(
    _MB_DOT_CLANG_FORMAT_ALREADY_RAN
    GLOBAL
    PROPERTY _MB_DOT_CLANG_FORMAT_AUTO_INSTALL_RAN
)
if(NOT _MB_DOT_CLANG_FORMAT_ALREADY_RAN)
    set_property(GLOBAL PROPERTY _MB_DOT_CLANG_FORMAT_AUTO_INSTALL_RAN TRUE)
    if(NOT MB_DOT_CLANG_FORMAT_NO_AUTO_INSTALL)
        mb_dot_clang_format_install()
    endif()
endif()
