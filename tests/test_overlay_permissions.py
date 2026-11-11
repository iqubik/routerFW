#!/usr/bin/env python3
# file: tests/test_overlay_permissions.py
"""Offline policy regressions: correct modes on both IB and SB staged trees.

Python tests execute under Windows too; Bash-only fixture cases are skipped there.
No Docker, OpenWrt build, network, root privilege, or NTFS dependency.
"""

from __future__ import annotations

import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
POLICY = REPO / "system" / "overlay_permissions.sh"
IB = REPO / "system" / "ib_builder.sh"
SB = REPO / "system" / "src_builder.sh"
COMPOSE = [REPO / "system" / s for s in
           ("docker-compose.yaml", "docker-compose-src.yaml")]


class PermissionWiring(unittest.TestCase):
    def test_single_policy_mounted_in_both_engines(self):
        for yaml_file in COMPOSE:
            text = yaml_file.read_text(encoding="utf-8")
            self.assertEqual(text.count("./overlay_permissions.sh:/overlay_permissions.sh"), 2)
        for builder in (IB, SB):
            content = builder.read_text(encoding="utf-8")
            self.assertIn("source /overlay_permissions.sh", content)
            self.assertIn('routerfw_normalize_overlay_permissions', content)
        self.assertIn('routerfw_normalize_overlay_permissions /tmp/clean_overlay',
                      IB.read_text(encoding="utf-8"))
        text = SB.read_text(encoding="utf-8")
        self.assertLess(text.index('routerfw_normalize_overlay_permissions "$stage"'),
                        text.index('lifecycle_clean_owned "$LIFECYCLE_FILES_STATE"'))

    def test_both_packers_embed_new_runtime_dependency_and_docs(self):
        files = [(REPO / "_packer.sh").read_text(encoding="utf-8"),
                 (REPO / "_packer.bat").read_text(encoding="utf-8-sig")]
        for content in files:
            self.assertIn('system/overlay_permissions.sh', content)
            self.assertIn('09-file-permissions.md', content)
            self.assertIn('09-file-permissions.en.md', content)

    def test_user_metadata_cannot_be_shipped_in_firmware(self):
        text = POLICY.read_text(encoding="utf-8")
        self.assertIn('rm -- "$metadata"', text)
        self.assertIn("[PERMISSIONS ERROR]", text)
        self.assertNotIn("chmod -R", text)
        self.assertNotIn("chown -R", text)


@unittest.skipUnless(sys.platform.startswith("linux") and shutil.which("bash"),
                     "POSIX Bash fixture required")
class PermissionPolicyFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="routerfw-perm-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.stage = self.root / "stage"
        self.stage.mkdir()

    def put(self, path: str, content: str = "probe", mode: int = 0o777):
        target = self.stage / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        target.chmod(mode)
        return target

    def chmod_dirs(self, mode: int = 0o777):
        for directory in self.stage.rglob("*"):
            if directory.is_dir():
                directory.chmod(mode)

    def normalize(self, expected: int = 0):
        completed = subprocess.run(
            ["bash", "-c", 'source "$1"; routerfw_normalize_overlay_permissions "$2"',
             "_", str(POLICY), str(self.stage)],
            capture_output=True, text=True)
        self.assertEqual(completed.returncode, expected,
                         f"stdout={completed.stdout}\nstderr={completed.stderr}")
        return completed

    def mode(self, relative: str):
        return stat.S_IMODE((self.stage / relative).stat().st_mode)

    def test_defaults_mode_data_script_directories(self):
        self.put("etc/routerfw/overlay-probe.txt")
        self.put("etc/uci-defaults/99-permissions.sh")
        self.put("etc/hotplug.d/iface/99-custom")
        self.put("etc/init.d/routerfw")
        self.put("usr/bin/custom-tool")
        self.put("etc/rc.button/wps")
        self.put("etc/profile.d/script.sh")
        self.chmod_dirs()
        self.normalize()
        self.assertEqual(self.mode("etc/routerfw/overlay-probe.txt"), 0o644)
        self.assertEqual(self.mode("etc/routerfw"), 0o755)
        self.assertEqual(self.mode("etc/uci-defaults/99-permissions.sh"), 0o644)
        self.assertEqual(self.mode("etc/hotplug.d/iface/99-custom"), 0o644)
        self.assertEqual(self.mode("etc/init.d/routerfw"), 0o755)
        self.assertEqual(self.mode("usr/bin/custom-tool"), 0o755)
        self.assertEqual(self.mode("etc/rc.button/wps"), 0o755)
        self.assertEqual(self.mode("etc/profile.d/script.sh"), 0o644)

    def test_secret_paths_and_public_keys(self):
        paths = ["root/.ssh/id_ed25519", "root/.ssh/id_ed25519.pub",
                 "root/.ssh/authorized_keys", "etc/dropbear/authorized_keys",
                 "etc/dropbear/dropbear_ed25519_host_key", "etc/shadow",
                 "etc/ssl/private/cert.key", "etc/wireguard/wg0.key",
                 "etc/ppp/chap-secrets", "etc/config/network"]
        for path in paths:
            self.put(path)
        self.normalize()
        for path in paths[:-1]:
            self.assertEqual(self.mode(path), 0o644 if path.endswith(".pub") else 0o600, path)
        self.assertEqual(self.mode("etc/config/network"), 0o644)
        self.assertEqual(self.mode("root"), 0o750)
        for path in ("root/.ssh", "etc/dropbear", "etc/ssl/private", "etc/wireguard"):
            self.assertEqual(self.mode(path), 0o700)

    def test_metadata_explicit_modes_crlf_bom_and_space(self):
        self.put("etc/routerfw/with space.txt")
        self.put("etc/routerfw/key-file")
        self.put(".routerfw-permissions", "\ufeff0640 /etc/routerfw/with space.txt\r\n0600 etc/routerfw/key-file\r\n0750 /etc/routerfw\r\n")
        self.normalize()
        self.assertEqual(self.mode("etc/routerfw/with space.txt"), 0o640)
        self.assertEqual(self.mode("etc/routerfw/key-file"), 0o600)
        self.assertEqual(self.mode("etc/routerfw"), 0o750)
        self.assertFalse((self.stage / ".routerfw-permissions").exists())

    def test_never_change_host_overlay(self):
        host = self.root / "input"
        data = host / "etc" / "routerfw" / "foo.txt"
        data.parent.mkdir(parents=True)
        data.write_text("host")
        data.chmod(0o777)
        (host / "etc" / "routerfw").chmod(0o777)
        shutil.copytree(host, self.stage, dirs_exist_ok=True)
        self.normalize()
        self.assertEqual(stat.S_IMODE(data.stat().st_mode), 0o777)
        self.assertEqual(self.mode("etc/routerfw/foo.txt"), 0o644)
        self.assertEqual(data.read_text(), (self.stage / "etc/routerfw/foo.txt").read_text())

    def test_mode_change_without_content_change(self):
        path = self.put("etc/routerfw/config.ini", "unchanged")
        self.put(".routerfw-permissions", "0600 /etc/routerfw/config.ini\n")
        self.normalize()
        self.assertEqual(self.mode("etc/routerfw/config.ini"), 0o600)
        self.put(".routerfw-permissions", "0644 /etc/routerfw/config.ini\n")
        self.normalize()
        self.assertEqual(self.mode("etc/routerfw/config.ini"), 0o644)
        self.assertEqual(path.read_text(), "unchanged")

    def test_reject_symlinks_even_to_in_tree_file(self):
        file = self.put("etc/routerfw/data")
        (file.parent / "link").symlink_to(file)
        result = self.normalize(expected=1)
        self.assertIn("Unsupported file type/symlink", result.stderr)
        self.assertEqual(self.mode("etc/routerfw/data"), 0o777)

    def test_reject_symlink_escape(self):
        (self.stage / "etc").symlink_to(self.root)
        result = self.normalize(expected=1)
        self.assertIn("Unsupported file type/symlink", result.stderr)

    def test_reject_fifo(self):
        os.mkfifo(self.stage / "fifo")
        result = self.normalize(expected=1)
        self.assertIn("Unsupported file type/symlink", result.stderr)

    def test_reject_invalid_metadata_before_chmod(self):
        self.put("etc/routerfw/probe", "test", 0o777)
        for spec in ("0777 /etc/routerfw/probe\n", "4755 /etc/routerfw/probe\n",
                     "0644 /etc/../etc/shadow\n", "0644 /etc/missing\n",
                     "0644 etc/routerfw/probe\n0600 /etc/routerfw/probe\n",
                     "0600 /etc/routerfw\n",  # directory cannot become non-traversable
                     "0100 /etc/routerfw\n",  # owner cannot list the directory
                     "0200 /etc/routerfw/probe\n",  # owner cannot read file for packing
                     "123456 /etc/routerfw/probe\n"):
            self.put(".routerfw-permissions", spec)
            self.normalize(expected=1)
            self.assertEqual(self.mode("etc/routerfw/probe"), 0o777, spec)
            self.assertTrue((self.stage / ".routerfw-permissions").exists())

    @unittest.skipUnless(shutil.which("rsync") and shutil.which("git"),
                         "Real rsync/git fixture unavailable")
    def test_real_sb_lifecycle_rsync_stages_permissions_on_off(self):
        work = self.root / "work"
        work.mkdir()
        overlay = self.root / "input"
        probe = overlay / "etc" / "routerfw" / "probe.txt"
        probe.parent.mkdir(parents=True)
        probe.write_text("v1", encoding="utf-8")
        probe.chmod(0o777)
        source = SB.read_text(encoding="utf-8")
        begin = source.index("# BEGIN SOURCE OVERLAY LIFECYCLE HELPERS")
        end = source.index("# END SOURCE OVERLAY LIFECYCLE HELPERS")
        functions = work / "functions.sh"
        functions.write_text(source[begin:end].split("\n", 1)[1], encoding="utf-8")
        test_script = self.root / "integration.sh"
        test_script.write_text(
            'set -e\n'
            'source "$1"\n'
            'source "$2"\n'
            'cd "$3"\n'
            'git init -q\n'
            'export ROUTERFW_FILES_SOURCE="$4"\n'
            'source_prepare_files\n'
            'source_record_files\n'
            'test "$(stat -c %a files/etc/routerfw/probe.txt)" = 644\n'
            'test "$(stat -c %a "$4/etc/routerfw/probe.txt")" = 777\n'
            'rm "$4/etc/routerfw/probe.txt"\n'
            'source_prepare_files\n'
            'source_record_files\n'
            'test ! -e files/etc/routerfw\n', encoding="utf-8")
        result = subprocess.run(
            ["bash", str(test_script), str(POLICY), str(functions), str(work), str(overlay)],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + "\n" + result.stderr)

    def test_own_files_only_and_no_metadata(self):
        self.put("etc/routerfw/probe")
        self.put(".routerfw-permissions", "# comment\n\n0640 /etc/routerfw/probe\n")
        self.normalize()
        self.assertEqual(sorted(x.name for x in self.stage.iterdir()), ["etc"])
        self.assertFalse((self.stage / ".routerfw-permissions").exists())


if __name__ == "__main__":
    unittest.main()
