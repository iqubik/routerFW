#!/usr/bin/env python3
# file: tests/test_tester_parity.py
"""Ensure shared test declarations stay mirrored across Bash and CMD harnesses.

Platform-only checks are explicitly allowed. Matching total test counts alone
would not detect a missing shared regression or provide behavioral parity.
"""

from __future__ import annotations

import re
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
import temp_support

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
    def test_exit_goodbye_waits_three_seconds_and_accepts_any_key(self):
        shell = (REPO / "_Builder.sh").read_text(encoding="utf-8")
        batch = (REPO / "_Builder.bat").read_text(encoding="utf-8-sig")
        self.assertRegex(shell, r'read -r -n 1 -s -t 3 \|\| true')
        self.assertRegex(batch, r'(?i)timeout /t 3 >nul 2>&1')

    @unittest.skipUnless(sys.platform.startswith("linux"), "Requires POSIX signal behavior")
    def test_runtime_probe_suppresses_child_signal_diagnostic(self):
        builder = (REPO / "_Builder.sh").read_text(encoding="utf-8")
        helper = re.search(r"(?ms)^runtime_probe\(\) \{\n.*?^\}", builder)
        self.assertIsNotNone(helper, "Runtime probe helper is missing")
        self.assertIn("runtime_probe docker info", builder)
        self.assertIn("runtime_probe docker.exe info", builder)
        with tempfile.TemporaryDirectory(prefix="routerfw-runtime-probe-") as directory:
            docker = Path(directory) / "docker"
            docker.write_text("#!/bin/sh\nulimit -c 0\nkill -BUS $$\n", encoding="utf-8")
            docker.chmod(0o755)
            proc = subprocess.run(
                ["bash", "-c", helper.group() + "\nruntime_probe docker info"],
                env={"PATH": f"{directory}:/usr/bin:/bin"},
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(proc.returncode, 0)
        self.assertNotIn("Bus error", proc.stderr)

    def test_cli_labels_mirror(self):
        sh_cli, _ = _labels(REPO / "tester.sh", windows=False)
        bat_cli, _ = _labels(REPO / "tester.bat", windows=True)
        self.assertEqual(sh_cli, bat_cli, "CLI test declarations differ")
        self.assertGreater(len(sh_cli), 30)

    def test_profile_menu_uses_shared_ordinal_sort(self):
        shell = (REPO / "_Builder.sh").read_text(encoding="utf-8")
        batch = (REPO / "_Builder.bat").read_text(encoding="utf-8-sig")
        self.assertIn("LC_ALL=C sort", shell)
        self.assertIn("[StringComparer]::Ordinal", batch)
        profiles = ["cmcc_rax3000me_24105_iw_full.conf",
                    "cmcc_rax3000m_24105_iw_full.conf"]
        self.assertEqual(sorted(profiles, key=lambda name: name.encode("ascii")),
                         ["cmcc_rax3000m_24105_iw_full.conf",
                          "cmcc_rax3000me_24105_iw_full.conf"])

    def test_common_health_checks_and_documented_platform_exceptions(self):
        _, sh = _labels(REPO / "tester.sh", windows=False)
        _, bat = _labels(REPO / "tester.bat", windows=True)
        self.assertEqual(sh - bat, BASH_ONLY)
        self.assertEqual(bat - sh, BATCH_ONLY)
        self.assertIn("Python Regression Suite", sh & bat)
        self.assertNotIn("Source Tree Packager", sh | bat)
        self.assertFalse(any(label.startswith("Packer ") for label in sh | bat))

    def test_source_builder_regression_runs_storage_git_feeds_and_lifecycle(self):
        harness = (REPO / "tester.sh").read_text(encoding="utf-8")
        self.assertRegex(
            harness,
            r'run_check 0 "Source Builder Storage Recovery" "bash tests/test_src_builder_storage\.sh && bash tests/test_src_builder_git_feeds\.sh && bash tests/test_src_builder_lifecycle\.sh"',
        )

    def test_python_test_launches_disable_bytecode_and_prefer_local_runtime(self):
        helper = (REPO / "scripts" / "python_runtime.bat").read_text(encoding="utf-8")
        self.assertIn(r"tools\runtime\python313\python.exe", helper)
        self.assertIn("ROUTERFW_PYTHON_EXE", helper)
        self.assertIn('set "PYTHONUTF8=1"', helper)
        self.assertIn(" -B -c ", helper)
        for filename, required in (
            ("tester.sh", "python3 -B tests/run_unittest.py"),
            ("tester.bat", "-B tests/run_unittest.py"),
            ("testgate.bat", "-B \"%~dp0testgate.py\""),
            ("package_source_zip.bat", "-B \"%~dp0package_source_zip.py\""),
        ):
            self.assertIn(required, (REPO / filename).read_text(encoding="utf-8-sig"))

    @unittest.skipUnless(os.name == "nt", "Batch override behavior needs Windows")
    def test_repository_python_explicit_override_is_preserved(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-python-override-") as scratch:
            check = Path(scratch) / "probe.bat"
            helper = REPO / "scripts" / "python_runtime.bat"
            check.write_text(
                '@echo off\ncall "' + str(helper) + '"\n'
                'if /i "%ROUTERFW_PYTHON_EXE%"=="' + sys.executable + '" (exit /b 0)\n'
                'exit /b 1\n', encoding="utf-8"
            )
            proc = subprocess.run(["cmd.exe", "/d", "/c", str(check)],
                                  capture_output=True, text=True, timeout=12,
                                  env={**os.environ, "ROUTERFW_PYTHON_EXE": sys.executable})
            self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)

    def test_repository_python_runtime_and_internal_tools_are_not_packed(self):
        for filename in ("_packer.sh", "_packer.bat"):
            packer = (REPO / filename).read_text(encoding="utf-8-sig")
            self.assertNotIn("tools/runtime/python313", packer)
            self.assertNotIn("python_runtime.bat", packer)
            self.assertNotIn("scripts/validate_build.py", packer)

    def test_windows_ci_runs_the_same_batch_test_harness(self):
        workflow = (REPO / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
        windows_job = workflow.split("  windows-tests:", 1)[1].split("  docker-smoke:", 1)[0]
        self.assertRegex(windows_job, r"(?m)^\s+run:\s+\.\\tester\.bat\s*$")
        tester = (REPO / "tester.bat").read_text(encoding="utf-8-sig")
        self.assertIn('call "%~dp0scripts\\python_runtime.bat"', tester)

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
