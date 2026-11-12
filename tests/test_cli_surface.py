#!/usr/bin/env python3
# file: tests/test_cli_surface.py
"""SH/BAT CLI contract regression without Docker/Podman or firmware compilation."""

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from bash_runner import bash_executable, bash_environment

REPO = Path(__file__).resolve().parents[1]


def invoke(name, *args, input_text=None, cwd=REPO, runtime=None):
    env = dict(os.environ, ROUTERFW_TEST_MODE="1", ROUTERFW_NO_CLS="1", TERM="dumb")
    if runtime is not None:
        env["ROUTERFW_RUNTIME"] = runtime
    if name == "sh":
        # Execute the checked interpreter, not an unrelated bash on PATH.
        # The -c wrapper keeps argument quoting intact across Win32/MSYS/WSL.
        cmd = [bash_executable(), "-c", 'exec "$BASH" ./_Builder.sh "$@"',
               "routerfw-cli-test", "--lang=EN", *args]
        env = bash_environment(env)
    elif name == "bat":
        cmd = ["cmd.exe", "/d", "/c", "call", "_Builder.bat", "--lang=EN", *args]
    else:
        raise ValueError(name)
    # Windows text=True converts LF to CRLF before writing to stdin. WSL Bash
    # then sees a literal trailing CR, so entering "0" becomes "0\r" and fails
    # the cancellation check. Feed protocol-native bytes without translation.
    payload = None
    if input_text is not None:
        payload = input_text.encode("utf-8")
        if name == "bat":
            payload = payload.replace(b"\n", b"\r\n")
    p = subprocess.run(cmd, input=payload, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=30, env=env, cwd=cwd)
    from types import SimpleNamespace
    return SimpleNamespace(returncode=p.returncode,
                           stdout=p.stdout.decode("utf-8", "replace"))


class CliSurfaceParity(unittest.TestCase):
    def test_runtime_accepts_mixed_case_and_rejects_unknown(self):
        platforms = ["sh", "bat"] if os.name == "nt" else ["sh"]
        for platform in platforms:
            for args in [("--runtime=DoCkEr", "help"),
                         ("--runtime", "PODMAN", "help"),
                         ("-r", "AuTo", "help")]:
                with self.subTest(platform=platform, args=args):
                    p = invoke(platform, *args)
                    self.assertEqual(p.returncode, 0, p.stdout[-1200:])
            p = invoke(platform, "--runtime=invalid", "help")
            self.assertNotEqual(p.returncode, 0, p.stdout[-1200:])

    def test_help_lists_all_aliases_and_actual_contract(self):
        for platform in (["sh", "bat"] if os.name == "nt" else ["sh"]):
            p = invoke(platform, "help")
            self.assertEqual(p.returncode, 0, p.stdout[-1200:])
            for expected in ["build_all", "[id/All]", "[1-6/1-3]", "edit, e",
                             "parallel", "sequential", "SOURCE unsupported", "source menuconfig 1"]:
                with self.subTest(platform=platform, expected=expected):
                    self.assertIn(expected, p.stdout)
            self.assertNotIn("source build-all", p.stdout)

    def test_edit_without_id_selects_or_cancels(self):
        platforms = ["sh", "bat"] if os.name == "nt" else ["sh"]
        for platform in platforms:
            with self.subTest(platform=platform, choice="cancel"):
                p = invoke(platform, "edit", input_text="0\n")
                self.assertEqual(p.returncode, 0, p.stdout[-1200:])
            with self.subTest(platform=platform, choice="invalid"):
                p = invoke(platform, "edit", input_text="invalid\n")
                self.assertNotEqual(p.returncode, 0, p.stdout[-1200:])

    def test_build_all_alias_dispatched_and_source_refused(self):
        platforms = ["sh", "bat"] if os.name == "nt" else ["sh"]
        for platform in platforms:
            for alias in ["build-all", "build_all"]:
                with self.subTest(platform=platform, alias=alias):
                    p = invoke(platform, "src", alias)
                    self.assertNotEqual(p.returncode, 0, p.stdout[-1500:])
                    # This must be the source-build restriction, not "profile not found".
                    self.assertNotIn("Profile not found", p.stdout)
                    self.assertNotIn("Specify profile", p.stdout)

    def test_checksum_all_and_global_clear_fail_without_unpacker(self):
        # Copy only the host script plus localization into an isolated workspace;
        # never mutate the actual repository's generated unpackers.
        with tempfile.TemporaryDirectory(prefix="routerfw-cli-contract-") as d:
            root = Path(d)
            (root / "system" / "lang").mkdir(parents=True)
            (root / "profiles").mkdir()
            for name in ["sh", "bat"]:
                shutil.copy2(REPO / ("_Builder." + name), root / ("_Builder." + name))
            for locale in ["en.env", "ru.env"]:
                shutil.copy2(REPO / "system" / "lang" / locale,
                             root / "system" / "lang" / locale)
            shutil.copy2(REPO / "system" / "version.env", root / "system" / "version.env")
            (root / "profiles" / "dummy.conf").write_text('PROFILE_NAME="dummy"\nTARGET_PROFILE="dummy"\n', encoding="utf-8")
            platforms = ["sh", "bat"] if os.name == "nt" else ["sh"]
            for platform in platforms:
                for command in ["check-all", "check-clear"]:
                    with self.subTest(platform=platform, command=command):
                        p = invoke(platform, command, cwd=root)
                        self.assertNotEqual(p.returncode, 0, p.stdout[-1500:])

    def test_source_contract_in_batch_and_bash(self):
        sh = (REPO / "_Builder.sh").read_text(encoding="utf-8")
        bat = (REPO / "_Builder.bat").read_text(encoding="utf-8")
        self.assertIn('BUILD-ALL|BUILD_ALL|ALL|A)', sh)
        self.assertIn('if /i "!c1!"=="build_all" set "CLI_CMD=BUILD_ALL"', bat)
        self.assertRegex(sh, r'CHECKSUM_ALL\)\s+do_checksum_all\s+exit \$\?')
        self.assertIsNotNone(re.search(r'CHECKSUM_CLEAR\).*?do_checksum_clear "\$CLI_ARG1"\s+exit \$\?', sh, re.S))
        self.assertIn('if not defined CLI_ARG1 (\n    set "ROUTERFW_CLI_EDIT_PICKER=1"\n    goto EDIT_PROFILE\n)', bat)
        self.assertIn('goto CLI_BUILD_ALL_DENIED', bat)
        self.assertIn(':CLI_BUILD_ALL_DENIED', bat)
        self.assertIn('if defined CLI_CMD exit /b 0', bat)
        self.assertIn('_val="${_val,,}"', sh)
        # Intentional divergence in scheduling policy, not command API.
        self.assertIn('ROUTERFW_JOBS', sh)
        self.assertIn(':BUILD_ALL', bat)


if __name__ == "__main__":
    unittest.main()
