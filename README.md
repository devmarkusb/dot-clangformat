# dot-clangformat

[![CI](https://github.com/devmarkusb/dot-clangformat/actions/workflows/ci.yml/badge.svg)](https://github.com/devmarkusb/dot-clangformat/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Boost-blue.svg)](LICENSE)

Single source of truth for `.clang-format`: versioned presets under `configs/vN/` (options available up to
LLVM/clang-format major **N**). Consumer CMake projects can pull this repository with **FetchContent** and, at configure
time, install the **highest bundled preset whose `N` is less than or equal to** the major version of `clang-format` you
actually run (for example the one pinned in **pre-commit**).

## CMake (FetchContent)

At the **top-level** `CMakeLists.txt` of your project (so `CMAKE_SOURCE_DIR` is your repo root), add a `FetchContent`
block and point it at this repository. `FetchContent_MakeAvailable` loads this repo’s `CMakeLists.txt`, which includes
`cmake/mb-dot-clang-format.cmake` and copies the chosen `configs/vN/.clang-format` to **`${CMAKE_SOURCE_DIR}/.clang-format`**
by default.

```cmake
include(FetchContent)
FetchContent_Declare(
    dot-clangformat
    GIT_REPOSITORY https://github.com/devmarkusb/dot-clangformat.git
    GIT_TAG main
)
FetchContent_MakeAvailable(dot-clangformat)
```

Re-configure your build (`cmake -S ... -B ...`) whenever you change the effective `clang-format` major version or when
you bump this dependency, so the copied file stays aligned.

### Cache / configure options

| Variable                                  | Default                             | Meaning                                                                                                                                                 |
|-------------------------------------------|-------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `MB_DOT_CLANG_FORMAT_ENABLE`              | `ON`                                | Defaults to **`OFF`** when this repo is the top-level project, **`ON`** when embedded via FetchContent. Set to `OFF` to **opt out** (no copy, no checks). |
| `MB_DOT_CLANG_FORMAT_OUTPUT`              | `${CMAKE_SOURCE_DIR}/.clang-format` | Destination path for the installed file.                                                                                                                |
| `MB_DOT_CLANG_FORMAT_CLANG_FORMAT_MAJOR`  | *(empty)*                           | **Major** version of `clang-format` to target (e.g. `17`). If empty, the module runs `clang-format --version` from `PATH` and parses the major version. |
| `MB_DOT_CLANG_FORMAT_FORCE_CONFIG_VERSION`| *(empty)*                           | If set (e.g. `14` or `22`), always use `configs/vN/` for that `N`, ignoring detection and compatibility picking.                                        |
| `MB_DOT_CLANG_FORMAT_QUIET`               | `OFF`                               | Suppress status messages from this module.                                                                                                              |

**Choosing the preset:** among bundled `configs/vN/`, the module selects the **largest `N` such that `N <=` your
clang-format major** (either from `MB_DOT_CLANG_FORMAT_CLANG_FORMAT_MAJOR` or from `clang-format --version`). Example:
bundled `v14` and `v22`, major `18` → `v14`; major `25` → `v22`.

**Opt-out:** configure with `-DMB_DOT_CLANG_FORMAT_ENABLE=OFF`, or `set(MB_DOT_CLANG_FORMAT_ENABLE OFF CACHE BOOL "" FORCE)`
**before** `FetchContent_MakeAvailable(dot-clangformat)` in the same `CMakeLists.txt`.

---

## What you still do by hand (not automated)

These steps are intentionally left to the consumer; they are **not** performed by this repo’s CMake.

1. **Match pre-commit’s `clang-format` to CMake**  
   Pre-commit runs the formatter from its own environment (hook `rev`, `mirrors-clang-format`, Docker, etc.). That
   binary may **not** be the same as `clang-format` on your `PATH` when CMake runs. To avoid picking the wrong
   `configs/vN/`, set **`MB_DOT_CLANG_FORMAT_CLANG_FORMAT_MAJOR`** to the major version of the formatter pre-commit uses (
   read it from your `.pre-commit-config.yaml`, hook docs, or by running the hook /
   `pre-commit run clang-format --verbose` and checking which binary/version runs).  
   Alternatively, ensure the only `clang-format` on `PATH` during CMake configuration is the same major as pre-commit (
   same container, `direnv`, etc.).

2. **Keep the copied `.clang-format` in version control (or not)**  
   The module writes into your source tree (by default the project root). Decide whether that file is **committed** or
   regenerated only locally; add ignore rules if you choose not to commit it.

3. **CI and non-CMake workflows**  
   If some pipelines **do not** run CMake, they will not refresh `.clang-format` from this repo. Either run a CMake
   configure step where needed, copy the appropriate `configs/vN/.clang-format` yourself in those jobs, or vendor the
   file another way.

4. **Bumping this dependency**  
   After changing `GIT_TAG` / branch for `dot-clangformat`, re-run CMake so the installed file updates. Resolve merge
   conflicts if both this module and humans edit `.clang-format`.

5. **`MB_DOT_CLANG_FORMAT_FORCE_CONFIG_VERSION`**  
   Use when you intentionally want a specific preset (e.g. team policy) regardless of detection, or when detection is
   impossible in a given environment.

---

## Developing this repository

- **CMake presets:** `CMakePresets.json` defines `default` (standalone configure; install stays off) and `ci-install`
  (enables `mb-dot-clang-format`, writes `build/ci-install/.clang-format`). Example: `cmake --preset default`.
- **CI:** [`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the `ci-install` preset and the Python installer,
  then checks the output against `configs/v22/.clang-format`.

## Layout

- `configs/vN/.clang-format` — preset using options up to clang-format major **N** (higher `N` may require a newer
  formatter to accept every key).
