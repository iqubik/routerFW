#!/usr/bin/env python3
# file: tests/test_bash_runner.py
"""Regression: Windows CI must not mistake an empty WSL launcher for Bash."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

import bash_runner


class BashSelection(unittest.TestCase):
    def tearDown(self):
        bash_runner.bash_executable.cache_clear()

    def test_posix_prefers_native_shell(self):
        if os.name != "nt":
            self.assertEqual(bash_runner.bash_executable(), "bash")

    def test_broken_wsl_falls_back_to_working_git_bash(self):
        failed = subprocess.CompletedProcess([], 1, b"", b"WSL has no distributions")
        working = subprocess.CompletedProcess([], 0, b"ROUTERFW_BASH_PROBE_OK", b"")
        with patch.object(bash_runner, "_candidates", return_value=["wsl-bash", "git-bash"]), \
                patch.object(bash_runner.os, "name", "nt"), \
                patch.object(bash_runner.subprocess, "run", side_effect=[failed, working]) as run:
            self.assertEqual(bash_runner.bash_executable(), "git-bash")
            self.assertEqual(run.call_count, 2)

    def test_first_working_bash_is_preserved(self):
        working = subprocess.CompletedProcess([], 0, b"ROUTERFW_BASH_PROBE_OK", b"")
        with patch.object(bash_runner, "_candidates", return_value=["wsl-bash", "git-bash"]), \
                patch.object(bash_runner.os, "name", "nt"), \
                patch.object(bash_runner.subprocess, "run", return_value=working) as run:
            self.assertEqual(bash_runner.bash_executable(), "wsl-bash")
            self.assertEqual(run.call_count, 1)

    def test_missing_all_bash_fails_closed(self):
        failed = subprocess.CompletedProcess([], 1, b"", b"missing")
        with patch.object(bash_runner, "_candidates", return_value=["wsl-bash", "git-bash"]), \
                patch.object(bash_runner.os, "name", "nt"), \
                patch.object(bash_runner.subprocess, "run", return_value=failed):
            with self.assertRaisesRegex(RuntimeError, "No compatible Bash"):
                bash_runner.bash_executable()

    def test_probe_rejects_a_non_bash_shell(self):
        shell = bash_runner.shutil.which("sh")
        if not shell:
            self.skipTest("sh not available")
        with patch.dict(os.environ, {"ROUTERFW_TEST_BASH": shell}):
            with self.assertRaisesRegex(RuntimeError, "No compatible Bash"):
                bash_runner.bash_executable()

    def test_probe_checks_real_file_operations(self):
        self.assertIn('"$BASH" -n ./_Builder.sh', bash_runner._PROBE)
        self.assertIn("sed -i", bash_runner._PROBE)
        self.assertIn("mktemp -d", bash_runner._PROBE)
        self.assertIn("BASH_VERSION", bash_runner._PROBE)

    def test_windows_tmpdir_is_normalized(self):
        with patch.object(bash_runner.os, "name", "nt"):
            result = bash_runner.bash_environment({"TMPDIR": r"C:\\Users\\user\\Temp", "OTHER": "test"})
            self.assertEqual(result["TMPDIR"], "/tmp")
            self.assertEqual(result["OTHER"], "test")

    def test_explicit_override_does_not_fallback(self):
        with patch.dict(os.environ, {"ROUTERFW_TEST_BASH": "custom-bash"}), \
                patch.object(bash_runner.shutil, "which", return_value="ignored"):
            self.assertEqual(bash_runner._candidates(), ["custom-bash"])


if __name__ == "__main__":
    unittest.main()
