#!/usr/bin/env python3
"""Copy the best matching configs/vN/.clang-format into the consumer tree.

Used by cmake/mb-dot-clang-format.cmake at configure time, or run directly for a one-shot sync
(e.g. CI or non-CMake workflows)::

    python /path/to/mb-dot-clang-format.py --output /your/project/.clang-format

Version probing uses a short subprocess timeout so a broken ``clang-format`` cannot hang configure.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

# Seconds; avoids a hung `clang-format --version` stalling CMake configure.
_VERSION_PROBE_TIMEOUT_SEC = 2


def _max_suffix_major(repo_root: Path | None) -> int:
    """Upper bound for clang-format-N names on PATH (bundled presets hint at what users install)."""
    extra_headroom = 5
    cap = 40
    if repo_root is None:
        return cap
    vers = collect_config_versions(repo_root)
    if not vers:
        return cap
    return min(cap, max(vers) + extra_headroom)


def _iter_clang_format_names(repo_root: Path | None):
    """Prefer unversioned `clang-format`, then `clang-format-N` from high N downward."""
    yield "clang-format"
    for n in range(_max_suffix_major(repo_root), 0, -1):
        yield f"clang-format-{n}"


def _repo_root_default() -> Path:
    return Path(__file__).resolve().parent.parent


def collect_config_versions(repo_root: Path) -> list[int]:
    configs = repo_root / "configs"
    if not configs.is_dir():
        return []
    versions: list[int] = []
    for p in configs.iterdir():
        m = re.fullmatch(r"v(\d+)", p.name)
        if m and p.is_dir():
            versions.append(int(m.group(1)))
    return sorted(versions)


def parse_version_major(text: str) -> int | None:
    """Parse major version from `clang-format --version` output; avoid loose matches on unrelated text."""
    m = re.search(r"clang-format version (\d+)", text, flags=re.IGNORECASE)
    if m:
        return int(m.group(1))
    for line in text.splitlines():
        line_s = line.strip()
        if "clang-format" not in line_s.lower():
            continue
        m = re.search(r"\bversion (\d+)\.\d", line_s)
        if m:
            return int(m.group(1))
    return None


def find_clang_format(explicit: str | None, repo_root: Path | None = None) -> str | None:
    if explicit:
        p = Path(explicit)
        if p.is_file():
            return str(p.resolve())
        return shutil.which(explicit)
    for name in _iter_clang_format_names(repo_root):
        found = shutil.which(name)
        if found:
            return found
    return None


def read_major_from_clang_format(clang_format: str) -> int | None:
    try:
        proc = subprocess.run(
            [clang_format, "--version"],
            check=False,
            capture_output=True,
            text=True,
            timeout=_VERSION_PROBE_TIMEOUT_SEC,
        )
    except OSError:
        return None
    except subprocess.TimeoutExpired:
        print(
            f"mb-dot-clang-format: timed out after {_VERSION_PROBE_TIMEOUT_SEC}s running "
            f"{clang_format!r} --version",
            file=sys.stderr,
        )
        return None
    combined = (proc.stdout or "") + (proc.stderr or "")
    return parse_version_major(combined)


def pick_config_version(clang_major: int, available: list[int]) -> int | None:
    for n in sorted(available, reverse=True):
        if n <= clang_major:
            return n
    return None


def run_sync(
    *,
    repo_root: Path,
    output: Path,
    clang_format_major: int | None,
    force_config_version: int | None,
    clang_format_exe: str | None,
    quiet: bool,
) -> None:
    available = collect_config_versions(repo_root)
    if not available:
        print(
            f"mb-dot-clang-format: no configs under {repo_root}/configs/v*",
            file=sys.stderr,
        )
        raise SystemExit(1)

    if force_config_version is not None:
        picked = force_config_version
        if picked not in available:
            avail = ", ".join(str(v) for v in available)
            print(
                f"mb-dot-clang-format: --force-config-version {picked} not found. "
                f"Available: {avail}",
                file=sys.stderr,
            )
            raise SystemExit(1)
    else:
        major = clang_format_major
        if major is None:
            cf = find_clang_format(clang_format_exe, repo_root)
            if not cf:
                print(
                    "mb-dot-clang-format: could not determine clang-format major version. "
                    "Set --clang-format-major (e.g. match pre-commit), "
                    "or --force-config-version, or install clang-format in PATH.",
                    file=sys.stderr,
                )
                raise SystemExit(1)
            major = read_major_from_clang_format(cf)
            if major is None:
                print(
                    f"mb-dot-clang-format: could not parse version from {cf} --version",
                    file=sys.stderr,
                )
                raise SystemExit(1)
        picked = pick_config_version(major, available)
        if picked is None:
            min_c = min(available)
            print(
                f"mb-dot-clang-format: no config compatible with clang-format major {major}. "
                f"Smallest bundled config is v{min_c}; upgrade clang-format or set "
                f"--force-config-version.",
                file=sys.stderr,
            )
            raise SystemExit(1)
        if not quiet:
            print(f"mb-dot-clang-format: clang-format major {major} -> configs/v{picked}")

    src = repo_root / "configs" / f"v{picked}" / ".clang-format"
    if not src.is_file():
        print(f"mb-dot-clang-format: missing {src}", file=sys.stderr)
        raise SystemExit(1)

    output = output.expanduser()
    out_path = Path(output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, out_path)
    if not quiet:
        print(f"mb-dot-clang-format: installed {out_path}")


def _build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Install bundled .clang-format preset matching your clang-format major.",
    )
    p.add_argument(
        "--repo-root",
        type=Path,
        default=_repo_root_default(),
        help="Root of mb-dot-clang-format (directory containing configs/). Default: parent of this script.",
    )
    p.add_argument(
        "--output",
        type=Path,
        default=Path.cwd() / ".clang-format",
        help="Destination file path (default: ./.clang-format in the current directory).",
    )
    p.add_argument(
        "--clang-format-major",
        type=int,
        default=None,
        metavar="N",
        help="Major version of clang-format to target; skips running clang-format --version.",
    )
    p.add_argument(
        "--force-config-version",
        type=int,
        default=None,
        metavar="N",
        help="Always use configs/vN/, ignoring compatibility picking.",
    )
    p.add_argument(
        "--clang-format",
        default=None,
        metavar="EXE",
        help="clang-format executable for version detection (optional; otherwise search PATH).",
    )
    p.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress status messages.",
    )
    return p


def main(argv: list[str] | None = None) -> None:
    args = _build_arg_parser().parse_args(argv)
    run_sync(
        repo_root=args.repo_root.resolve(),
        output=args.output,
        clang_format_major=args.clang_format_major,
        force_config_version=args.force_config_version,
        clang_format_exe=args.clang_format,
        quiet=args.quiet,
    )


if __name__ == "__main__":
    main()
