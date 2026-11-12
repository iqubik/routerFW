#!/usr/bin/env python3
# file: tests/test_builder_interactive_tty.py
"""Regressions for Menuconfig TTY handling and successful SB -> IB profile handoff.

No Docker, Podman or user profile is used; shell helpers are extracted verbatim
from _Builder.sh and executed with mocked external effects.
"""

from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = (ROOT / "_Builder.sh").read_text(encoding="utf-8")


def function(name: str) -> str:
    match = re.search(rf"(?ms)^{re.escape(name)}\(\) \{{\n.*?^\}}\n", SHELL)
    if match is None:
        raise AssertionError(f"Missing Bash function: {name}")
    return match.group(0)


HELPERS = "\n".join(function(name) for name in (
    "write_compose_env_file", "compose_files_for", "run_compose", "run_compose_interactive"
))


@unittest.skipUnless(sys.platform.startswith("linux"), "POSIX pseudo-terminal required")
class MenuconfigTty(unittest.TestCase):
    def test_wsl_bridge_interactive_compose_inherits_terminal_on_both_streams(self):
        import pty
        import select
        import time

        with tempfile.TemporaryDirectory(prefix="routerfw-tty-") as td:
            fake = Path(td) / "compose-mock"
            fake.write_text(
                "#!/bin/bash\n"
                "[ -t 0 ] && [ -t 1 ] || { echo 'NOT_A_TTY'; exit 71; }\n"
                "printf 'TTY_OK\\n'\n", encoding="utf-8"
            )
            fake.chmod(0o755)
            body = (HELPERS + "\n"
                    + "CONTAINER_RUNTIME=docker\nDOCKER_WINDOWS_BRIDGE=1\n"
                    + f'COMPOSE_CMD=("{fake}")\n'
                    + 'run_compose_interactive system/docker-compose-src.yaml -p sample run --rm -it service /bin/bash\n')
            sh = Path(td) / "invoke.sh"
            sh.write_text(body, encoding="utf-8")
            # Both routes must work: direct terminal descriptors and redirected
            # stdio *with* an existing controlling terminal (/dev/tty).
            for redirected_stdio in (False, True):
                with self.subTest(redirected_stdio=redirected_stdio):
                    pid, fd = pty.fork()
                    if pid == 0:
                        os.chdir(td)
                        if redirected_stdio:
                            # Child inherits the controlling TTY but its stdio
                            # is piped: run_compose_interactive must reattach.
                            result = subprocess.run(
                                ["/bin/bash", str(sh)], input="", text=True,
                                capture_output=True,
                            )
                            os._exit(result.returncode)
                        os.execl("/bin/bash", "bash", str(sh))
                    chunks = []
                    deadline = time.monotonic() + 7
                    status = None
                    while time.monotonic() < deadline:
                        ready, _, _ = select.select([fd], [], [], 0.2)
                        if ready:
                            try:
                                data = os.read(fd, 8192)
                            except OSError:
                                data = b""
                            if data:
                                chunks.append(data)
                        done, child_status = os.waitpid(pid, os.WNOHANG)
                        if done:
                            status = child_status
                            break
                    if status is None:
                        os.kill(pid, 9)
                        os.waitpid(pid, 0)
                        os.close(fd)
                        self.fail("Interactive Compose mock hung")
                    while True:
                        try:
                            remaining = os.read(fd, 8192)
                            if not remaining:
                                break
                            chunks.append(remaining)
                        except OSError:
                            break
                    os.close(fd)
                    output = b"".join(chunks).decode("utf-8", "replace")
                    self.assertEqual(os.waitstatus_to_exitcode(status), 0, output)
                    self.assertIn("TTY_OK", output)
                    self.assertNotIn("NOT_A_TTY", output)

    def test_interactive_compose_refuses_headless_stdin(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-headless-") as td:
            code = (HELPERS + "\n"
                    + 'CONTAINER_RUNTIME=docker\nDOCKER_WINDOWS_BRIDGE=0\n'
                    + 'COMPOSE_CMD=(/bin/true)\n'
                    + 'run_compose_interactive system/docker-compose-src.yaml -p sample run --rm -it service /bin/bash\n')
            # Redirected stdin alone does not mean headless: WSL may retain
            # /dev/tty even with captured stdio. A new session guarantees this
            # test has no controlling terminal on Linux/WSL.
            result = subprocess.run(
                ["bash", "-c", code], input="", text=True,
                capture_output=True, cwd=td, start_new_session=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("requires a terminal", result.stderr)

    def test_menuconfig_failure_does_not_process_old_manual_config(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-mc-fail-") as td:
            root = Path(td)
            (root / "profiles").mkdir()
            profile = root / "profiles" / "sample.conf"
            original = 'SRC_BRANCH="openwrt-25.12"\n'
            profile.write_text(original, encoding="utf-8")
            out = root / "firmware_output" / "sourcebuilder" / "sample"
            out.mkdir(parents=True)
            manual = out / "manual_config"
            manual.write_text("STALE_MENUCONFIG\n", encoding="utf-8")
            code = (function("run_menuconfig") + "\n"
                    + 'C_LBL= C_RST= C_KEY= C_VAL= L_K_LAUNCH=\n'
                    + 'run_compose_interactive() { return 77; }\n'
                    + 'run_menuconfig sample.conf\n')
            result = subprocess.run(["bash", "-c", code], input="", text=True, capture_output=True, cwd=td)
            self.assertEqual(result.returncode, 77, result.stdout + result.stderr)
            self.assertEqual(profile.read_text(encoding="utf-8"), original)
            self.assertEqual(manual.read_text(encoding="utf-8"), "STALE_MENUCONFIG\n")
            self.assertFalse((out / "_menuconfig_runner.sh").exists())


@unittest.skipUnless(sys.platform.startswith("linux"), "POSIX Bash required")
class SourceImagebuilderProfile(unittest.TestCase):
    def test_successful_sb_discovery_updates_active_profile_only_with_user_consent(self):
        """Simulate a successful SB build; verify its actual Bash profile-write path."""
        builder = ("\n".join(function(n) for n in (
            "source_profile_value", "source_output_snapshot", "source_output_new_dir",
            "source_output_ib_enabled", "source_output_ib_archive", "build_routine"
        )))
        for ib in (True, False):
            with self.subTest(ib=ib), tempfile.TemporaryDirectory(prefix="routerfw-ib-handoff-") as td:
                root = Path(td)
                (root / "profiles").mkdir()
                profile = root / "profiles" / "sample.conf"
                previous = 'IMAGEBUILDER_URL="https://example.org/old-imagebuilder.tar.zst"'
                profile.write_text(previous + '\nSRC_BRANCH="openwrt-25.12"\n', encoding="utf-8")
                code = (builder + "\n"
                        + 'C_LBL= C_RST= C_KEY= C_VAL= C_GRY= C_ERR= C_OK= C_CYAN= C_YEL=\n'
                        + 'L_IB_UPDATE_ASK= L_IB_UPDATE_PROMPT= L_IB_UPDATE_OK= L_K_STAY=\n'
                        + 'BUILD_MODE=SOURCE CLI_CMD="" SELECTED_CONF=sample.conf\n'
                        + 'check_dir() { mkdir -p "$1"; }\n'
                        + 'run_container() { :; }\n'
                        + 'sleep() { :; }\n'
                        + 'fix_output_ownership() { :; }\n'
                        + 'run_compose() {\n'
                        + '  if [[ " $* " == *" up "* ]]; then\n'
                        + '    mkdir -p "$HOST_OUTPUT_DIR/new-run"\n'
                        + ('    printf "CONFIG_IB=y\\n" > "$HOST_OUTPUT_DIR/new-run/build.config"\n' if ib
                           else '    printf "# CONFIG_IB is not set\\n" > "$HOST_OUTPUT_DIR/new-run/build.config"\n')
                        + '    printf "archive\\n" > "$HOST_OUTPUT_DIR/new-run/openwrt-imagebuilder.tar.zst"\n'
                        + '  fi\n'
                        + '}\n'
                        + 'build_routine sample.conf\n')
                result = subprocess.run(["bash", "-c", code], input="y\nn\n", text=True, capture_output=True, cwd=td)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                content = profile.read_text(encoding="utf-8")
                if ib:
                    self.assertIn('#' + previous, content)
                    self.assertIn('IMAGEBUILDER_URL="firmware_output/sourcebuilder/sample/new-run/openwrt-imagebuilder.tar.zst"', content)
                    self.assertEqual(sum(line.startswith('IMAGEBUILDER_URL=') for line in content.splitlines()), 1)
                else:
                    self.assertEqual(content, previous + '\nSRC_BRANCH="openwrt-25.12"\n')


if __name__ == "__main__":
    unittest.main()
