#!/usr/bin/env python3
# file: tests/test_profile_state.py
"""Functional state/s regression and cross-platform read-only scanner contract."""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
import temp_support
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


class StateScannerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="routerfw-state-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "profiles").mkdir()
        (self.root / "profiles/a.conf").write_text('SRC_ARCH="aarch64_generic"\n', encoding="utf-8")
        (self.root / "profiles/b.conf").write_text('PROFILE_NAME="empty"\n', encoding="utf-8")
        for item in ("custom_files/a/etc/config/network", "src_packages/a/pkg/Makefile",
                     "custom_patches/a/patch.diff", "firmware_output/imagebuilder/a/image.bin",
                     "firmware_output/sourcebuilder/a/firmware.img",
                     "firmware_output/sourcebuilder/a/manual_config", "custom_files/a/hooks.sh"):
            target = self.root / item
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("test\n", encoding="utf-8")
        # A directory by itself must not count as a BAT F/P/S/X/OI/OS file.
        (self.root / "custom_packages/a/empty-folder").mkdir(parents=True)
        (self.root / "firmware_output/imagebuilder/b/empty-folder").mkdir(parents=True)

    @staticmethod
    def embedded_scanner():
        lines = (REPO / "_Builder.bat").read_text(encoding="utf-8-sig").splitlines()
        start = lines.index("::PSPROFILESTATE:BEGIN") + 1
        end = lines.index("::PSPROFILESTATE:END", start)
        prefix = "::PSPROFILESTATE:"
        body = lines[start:end]
        if any(not line.startswith(prefix) for line in body):
            raise AssertionError("Malformed embedded profile-state scanner")
        return "\n".join(line[len(prefix):] for line in body) + "\n"

    def test_power_shell_scanner_checks_real_files_and_reports_phases(self):
        if os.name != "nt":
            self.skipTest("Native Windows PowerShell behavior is exercised on Windows CI")
        script = self.root / "profile_state_embedded.ps1"
        embedded = self.embedded_scanner()
        canonical = (REPO / "system/profile_state.ps1").read_text(encoding="utf-8-sig").splitlines()
        if canonical[-1].startswith("# checksum:MD5="):
            canonical.pop()
        self.assertEqual(embedded, "\n".join(canonical) + "\n")
        script.write_text(embedded, encoding="utf-8")
        p = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive",
                            "-ExecutionPolicy", "Bypass", "-File", str(script),
                            "-Root", str(self.root)], capture_output=True,
                           text=True, encoding="utf-8", errors="replace", timeout=25,
                           env={**os.environ, "ROUTERFW_STATE_PROFILE": "1"})
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.splitlines(), [
            "a|aarch64_generic|10111111", "b|--------|00000000"
        ])
        self.assertIn("[STATE-PROFILE] a arch=", p.stderr)
        self.assertIn("scan-total=", p.stderr)

    def test_batch_state_runs_embedded_scanner(self):
        if os.name != "nt":
            self.skipTest("Native Batch execution is exercised on Windows CI")
        (self.root / "system/lang").mkdir(parents=True)
        shutil.copy2(REPO / "_Builder.bat", self.root / "_Builder.bat")
        for name in ("en.env", "ru.env"):
            shutil.copy2(REPO / "system/lang" / name, self.root / "system/lang" / name)
        shutil.copy2(REPO / "system/version.env", self.root / "system/version.env")
        p = subprocess.run(
            ["cmd.exe", "/d", "/c", "_Builder.bat --lang=EN state"],
            cwd=self.root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30,
            env={**os.environ, "ROUTERFW_TEST_MODE": "1", "ROUTERFW_NO_CLS": "1",
                 "ROUTERFW_STATE_PROFILE": "1", "TERM": "dumb"},
        )
        self.assertEqual(p.returncode, 0, p.stderr[-1200:] + p.stdout[-1200:])
        output = ANSI.sub("", p.stdout)
        self.assertIn("aarch64_generic", output)
        self.assertIn("F·SMHX", output)
        self.assertIn("[STATE-PROFILE] a arch=", p.stderr)
        self.assertIn("[STATE-PROFILE] scan-total=", p.stderr)

    def test_sh_state_reports_first_file_in_deep_output_and_opt_in_timing(self):
        if os.name == "nt":
            self.skipTest("SH functional test is exercised by Linux/WSL runner")
        (self.root / "system/lang").mkdir(parents=True)
        for file in ("_Builder.sh",):
            shutil.copy2(REPO / file, self.root / file)
        for file in ("system/lang/en.env", "system/lang/ru.env", "system/version.env"):
            shutil.copy2(REPO / file, self.root / file)
        for command in ("state", "s"):
            with self.subTest(command=command):
                p = subprocess.run(["bash", "./_Builder.sh", "--lang=EN", command],
                                   cwd=self.root, capture_output=True, text=True,
                                   timeout=25,
                                   env={**os.environ, "ROUTERFW_TEST_MODE": "1",
                                        "ROUTERFW_STATE_PROFILE": "1", "TERM": "dumb"})
                self.assertEqual(p.returncode, 0, p.stderr[-1200:] + p.stdout[-1200:])
                output = ANSI.sub("", p.stdout)
                # Source tree has a file in every marked group except packages.
                self.assertIn("aarch64_generic", output)
                self.assertIn("F·SMHX | OI OS", output)
                self.assertNotIn("FPSMHX | OI OS", output)
                self.assertIn("[STATE-PROFILE] a arch=", p.stderr)
                self.assertIn("[STATE-PROFILE] scan-total=", p.stderr)

    def test_state_scanner_is_embedded_and_not_packaged_separately(self):
        self.assertNotIn('system/profile_state.ps1', (REPO / '_packer.sh').read_text(encoding="utf-8"))
        self.assertNotIn('system/profile_state.ps1', (REPO / '_packer.bat').read_text(encoding="utf-8-sig"))
        self.assertIn("::PSPROFILESTATE:BEGIN", (REPO / "_Builder.bat").read_text(encoding="utf-8-sig"))
        self.assertIn('state_file_present "firmware_output', (REPO / '_Builder.sh').read_text())


if __name__ == "__main__":
    unittest.main()
