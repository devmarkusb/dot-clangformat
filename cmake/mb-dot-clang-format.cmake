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
