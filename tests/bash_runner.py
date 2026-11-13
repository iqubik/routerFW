#!/usr/bin/env python3
# file: tests/bash_runner.py
"""Choose an actually working Bash for cross-platform Python contract tests.

On Windows, ``bash.exe`` may be a WSL launcher or an incompatible POSIX shim.
Prefer Git for Windows when installed; require real Bash syntax, script access,
and Unix-style temporary-file operations before accepting any candidate.
Never silently skip tests when no compatible Bash exists.
"""

from __future__ import annotations

from functools import lru_cache
import os
from pathlib import Path
import re
import shutil
import subprocess

# The previous printf-only probe accepted shells that later failed on actual
# scripts, or on mktemp/sed -i due to unconverted Windows temporary paths.
# Keep this probe side-effect-free outside its own temporary directory.
_PROBE = r"""set -e
[[ -n ${BASH_VERSION:-} ]]
_items=(ab cd)
[[ ${_items[0]^^} == AB ]]
_tmpdir=$(mktemp -d)
trap 'rm -rf -- "$_tmpdir"' EXIT
printf 'before\n' > "$_tmpdir/probe"
sed -i 's/before/after/' "$_tmpdir/probe"
[[ $(cat "$_tmpdir/probe") == after ]]
"$BASH" -n ./_Builder.sh
printf ROUTERFW_BASH_PROBE_OK
"""
_EXPECTED = b"ROUTERFW_BASH_PROBE_OK"
_TEST_REPO = Path(__file__).resolve().parents[1]
(_TEST_REPO / "tmp").mkdir(parents=True, exist_ok=True)


def _candidates() -> list[str]:
    override = os.environ.get("ROUTERFW_TEST_BASH")
    if override:
        # A caller's explicit choice should fail closed, never fall back.
        return [override]

    candidates: list[str] = []
    if os.name == "nt":
        for var in ("ProgramW6432", "ProgramFiles", "ProgramFiles(x86)"):
            root = os.environ.get(var)
            if root:
                candidates.append(str(Path(root) / "Git" / "bin" / "bash.exe"))
        git = shutil.which("git")
        if git:
            # Typical install: <Git>/cmd/git.exe, <Git>/bin/bash.exe.
            candidates.append(str(Path(git).resolve().parent.parent / "bin" / "bash.exe"))
    candidates.append(shutil.which("bash") or "bash")
    bash_exe = shutil.which("bash.exe")
    if bash_exe:
        candidates.append(bash_exe)

    # Git Bash is chosen first on Windows: a WSL launcher may pass bash -c
    # but mishandle Windows Python cwd/path or temp semantics. Explicit
    # ROUTERFW_TEST_BASH remains the opt-in for a specific interpreter.
    return list(dict.fromkeys(candidates))


def bash_environment(base: dict[str, str] | None = None) -> dict[str, str]:
    """Keep Bash fixture files in the ignored project scratch directory."""
    env = dict(os.environ if base is None else base)
    repo_tmp = str(_TEST_REPO / "tmp")
    if os.name == "nt":
        repo_tmp = repo_tmp.replace("\\", "/")
        if re.match(r"^[A-Za-z]:/", repo_tmp):
            repo_tmp = f"/{repo_tmp[0].lower()}/{repo_tmp[3:]}"
    env["TMPDIR"] = repo_tmp
    return env


@lru_cache(maxsize=1)
def bash_executable() -> str:
    """Return a Bash capable of executing commands, or raise an explicit error."""
    if os.name != "nt" and not os.environ.get("ROUTERFW_TEST_BASH"):
        return "bash"

    failures = []
    for candidate in _candidates():
        try:
            completed = subprocess.run(
                [candidate, "-c", _PROBE],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                timeout=15, check=False, cwd=_TEST_REPO,
                env=bash_environment(),
            )
            if completed.returncode == 0 and completed.stdout.strip() == _EXPECTED:
                return candidate
            failures.append(f"{candidate}: exit {completed.returncode}")
        except (OSError, subprocess.TimeoutExpired) as error:
            failures.append(f"{candidate}: {error}")
    raise RuntimeError(
        "No compatible Bash for routerFW Python regression tests (syntax, "
        "repository script, and mktemp/sed -i probe). "
        "Install a WSL distribution or Git for Windows, or explicitly set "
        "ROUTERFW_TEST_BASH to a working bash.exe. "
        + "; ".join(failures)
    )
