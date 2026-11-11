#!/usr/bin/env python3
# file: tests/test_tester_parity.py
"""Ensure shared test declarations stay mirrored across Bash and CMD harnesses.

Platform-only checks are explicitly allowed. Matching total test counts alone
would not detect a missing shared regression or provide behavioral parity.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# Intentionally platform-specific tests; document every exception here.
BASH_ONLY = frozenset({
    "Bash Syntax", "Shell Syntax", "ShellCheck", "Runtime WSL Podman Bridge",
    "Source Builder Storage Recovery",
})
BATCH_ONLY = frozenset({
    "Shell CALL Arguments", "Build Window Title", "Worktree Diff Helper Diagnostics",
    "Worktree Diff Helper ZIP Extension", "Worktree Diff Default Yes",
})


def _labels(path: Path, *, windows: bool) -> tuple[set[str], set[str]]:
    text = path.read_text(encoding="utf-8-sig")
    if windows:
        prefix = r"call :"
        health = r"run_ps"
    else:
        prefix = ""
        health = r"run_check"
    cli_re = re.compile(rf'^\s*{prefix}run(?:_env)?\s+\d+\s+"([^"]+)"', re.M)
    health_re = re.compile(rf'^\s*{prefix}{health}\s+\d+\s+"([^"]+)"', re.M)
    cli = cli_re.findall(text)
    checks = health_re.findall(text)
    if len(cli) != len(set(cli)) or len(checks) != len(set(checks)):
        raise AssertionError(f"Repeated test labels: {path}")
    return set(cli), set(checks)


class TesterParity(unittest.TestCase):
    def test_cli_labels_mirror(self):
        sh_cli, _ = _labels(REPO / "tester.sh", windows=False)
        bat_cli, _ = _labels(REPO / "tester.bat", windows=True)
        self.assertEqual(sh_cli, bat_cli, "CLI test declarations differ")
        self.assertGreater(len(sh_cli), 30)

    def test_common_health_checks_and_documented_platform_exceptions(self):
        _, sh = _labels(REPO / "tester.sh", windows=False)
        _, bat = _labels(REPO / "tester.bat", windows=True)
        self.assertEqual(sh - bat, BASH_ONLY)
        self.assertEqual(bat - sh, BATCH_ONLY)
        self.assertIn("Source Tree Packager", sh & bat)
        self.assertFalse(any(label.startswith("Packer ") for label in sh | bat))

    def test_source_builder_regression_runs_storage_git_feeds_and_lifecycle(self):
        harness = (REPO / "tester.sh").read_text(encoding="utf-8")
        self.assertRegex(
            harness,
            r'run_check 0 "Source Builder Storage Recovery" "bash tests/test_src_builder_storage\.sh && bash tests/test_src_builder_git_feeds\.sh && bash tests/test_src_builder_lifecycle\.sh"',
        )

    def test_github_workflow_runner_os_labels_are_pinned(self):
        # A GitHub runner image rolls forward even with a versioned label, but
        # ubuntu-latest/windows-latest would additionally change OS major release.
        workflows = sorted((REPO / ".github" / "workflows").glob("*.yml"))
        self.assertTrue(workflows)
        labels = []
        for file in workflows:
            content = file.read_text(encoding="utf-8")
            labels += re.findall(r"(?m)^\s*runs-on:\s*([^\s#]+)", content)
        self.assertGreaterEqual(len(labels), 6)
        self.assertEqual(set(labels), {"ubuntu-24.04", "windows-2025"})

    def test_declared_baseline_counts_mirror(self):
        sh_cli, sh_health = _labels(REPO / "tester.sh", windows=False)
        bat_cli, bat_health = _labels(REPO / "tester.bat", windows=True)
        self.assertEqual(len(sh_cli) + len(sh_health), len(bat_cli) + len(bat_health))
        self.assertGreaterEqual(len(sh_cli) + len(sh_health), 57)


if __name__ == "__main__":
    unittest.main()
