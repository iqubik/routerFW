#!/usr/bin/env python3
# file: tests/test_package_source_zip.py
"""No-Docker regression tests for routerFW source-tree ZIP exporter."""

from __future__ import annotations

import builtins
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).resolve().parents[1] / "package_source_zip.py"
spec = importlib.util.spec_from_file_location("routerfw_package_source_zip", SCRIPT)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class SourceZipTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="routerfw-sourcezip-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "routerFW with ! and & кириллица"
        self.root.mkdir()
        self._write("README.md", "routerFW\n")
        self.out = self.root / "routerFW_source.zip"

    def _write(self, relative, contents="test\n"):
        file = self.root / relative
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_bytes(contents.encode("utf-8"))
        return file

    def _names(self, archive=None):
        with zipfile.ZipFile(archive or self.out) as zf:
            self.assertIsNone(zf.testzip())
            return set(zf.namelist()) - {mod.TREE_INDEX_NAME}

    def test_core_code_agent_rules_profiles_ci_included(self):
        for name in ("_Builder.bat", "_Builder.sh", "system/src_builder.sh", "docs/audit.md",
                     ".cursor/rules/project-overview.mdc", ".github/workflows/tests.yml",
                     "profiles/router.conf", "GEMINI.md", "pub.md"):
            self._write(name)
        mod.create_source_zip(self.root, self.out)
        names = self._names()
        self.assertTrue({"README.md", "GEMINI.md", "pub.md", "profiles/router.conf",
                         ".github/workflows/tests.yml", ".cursor/rules/project-overview.mdc"} <= names)

    def test_all_six_requested_directories_excluded(self):
        for name in ("firmware_output", ".git", "builds", "bck", "nw_test", "nl_test"):
            self._write(f"{name}/deep/private.bin", "SECRET")
            self._write(f"{name}/deep/not-source.md", "NO")
        mod.create_source_zip(self.root, self.out)
        self.assertEqual(self._names(), {"README.md"})

    def test_real_document_named_debug_is_not_silently_excluded(self):
        self._write("docs/debug.md", "legitimate developer notes")
        self._write("debug.md", "root scratch file")
        mod.create_source_zip(self.root, self.out)
        self.assertEqual(self._names(), {"README.md", "docs/debug.md"})

    def test_generated_archives_unpackers_and_logs_excluded(self):
        for name in ("_unpacker.bat", "_unpacker.sh", "tester_log_lin.md", "tester_tmp_abc_out.txt",
                     "routerFW_LinuxDockerBuilder_v1.tar.gz", "old-overlay.zip", "flash.img",
                     "firmware.ipk", "libfoo.so", "script.exe", "image.bin", "debug.md"):
            self._write(name)
        self._write("_packer.sh")
        mod.create_source_zip(self.root, self.out)
        self.assertEqual(self._names(), {"README.md", "_packer.sh"})

    def test_private_custom_and_keys_skipped_by_default(self):
        for name in ("custom_files/a/hooks.sh", "custom_packages/a/foo.md",
                     "custom_patches/a/diff.patch", "src_packages/a/Makefile", "keys/signing.key",
                     ".env", ".env.production", "credentials.json", "docs/secrets.txt",
                     ".ssh/id_rsa", "docs/local.settings.md"):
            self._write(name)
        self._write(".env.example")
        mod.create_source_zip(self.root, self.out)
        self.assertEqual(self._names(), {"README.md", ".env.example"})

    def test_include_custom_is_explicit_and_keeps_secret_filters(self):
        self._write("custom_files/a/hooks.sh")
        self._write("custom_files/a/id_rsa")
        self._write("custom_packages/a/firmware.ipk")
        self._write("custom_patches/a/001.patch")
        self._write("src_packages/a/Makefile")
        self._write("keys/public.pem")
        mod.create_source_zip(self.root, self.out, include_custom=True)
        self.assertEqual(self._names(), {"README.md", "custom_files/a/hooks.sh",
                                          "custom_patches/a/001.patch", "src_packages/a/Makefile"})

    def test_large_file_guard_skips_without_failing(self):
        self._write("docs/large.txt", "z" * (1024 * 1024 + 1))
        mod.create_source_zip(self.root, self.out, max_file_mib=1)
        self.assertEqual(self._names(), {"README.md"})

    def test_default_max_file_size_excludes_extensionless_binary(self):
        # Source trees can contain compiled binaries without filename extensions.
        self._write("scripts/checker/RealiTLScanner-linux-64", "x" * (4 * 1024 * 1024 + 1))
        mod.create_source_zip(self.root, self.out)
        self.assertEqual(self._names(), {"README.md"})

    def test_checker_tools_are_excluded_from_source_archive(self):
        self._write("scripts/checker/checker.py")
        self._write("scripts/checker/findsni.sh")
        self._write("scripts/other.py")
        mod.create_source_zip(self.root, self.out)
        self.assertEqual(self._names(), {"README.md", "scripts/other.py"})

    def test_cyrillic_and_special_characters_preserved(self):
        name = "docs/Кириллица & ! (x).md"
        for newline in ("\n", "\r\n"):
            with self.subTest(newline=newline):
                contents = "привет" + newline
                self._write(name, contents)
                mod.create_source_zip(self.root, self.out)
                self.assertIn(name, self._names())
                with zipfile.ZipFile(self.out) as zf:
                    self.assertEqual(zf.read(name), contents.encode("utf-8"))

    def test_symlink_not_followed(self):
        outside = Path(self.tmp.name) / "outside-secret.txt"
        outside.write_text("secret", encoding="utf-8")
        try:
            (self.root / "linked.txt").symlink_to(outside)
        except (OSError, NotImplementedError):
            self.skipTest("No symlink permission")
        mod.create_source_zip(self.root, self.out)
        self.assertEqual(self._names(), {"README.md"})

    def test_second_run_does_not_include_previous_archive(self):
        mod.create_source_zip(self.root, self.out)
        mod.create_source_zip(self.root, self.out)
        self.assertEqual(self._names(), {"README.md"})
        self.assertFalse(list(self.root.glob(".*.tmp.zip")))

    def test_failed_creation_preserves_previous_zip(self):
        mod.create_source_zip(self.root, self.out)
        original = self.out.read_bytes()
        with patch.object(zipfile.ZipFile, "write", side_effect=OSError("test read error")):
            with self.assertRaises(mod.SourcePackagingError):
                mod.create_source_zip(self.root, self.out)
        self.assertEqual(self.out.read_bytes(), original)
        self.assertFalse(list(self.root.glob(".*.tmp.zip")))

    def test_enter_yes_n_no_invalid_reprompt(self):
        with patch.object(builtins, "input", side_effect=[""]):
            self.assertTrue(mod._ask_overwrite(self.out))
        with patch.object(builtins, "input", side_effect=["n"]):
            self.assertFalse(mod._ask_overwrite(self.out))
        with patch.object(builtins, "input", side_effect=["unknown", "Y"]):
            self.assertTrue(mod._ask_overwrite(self.out))

    def test_cli_cancel_preserves_old_archive(self):
        self.out.write_bytes(b"original")
        proc = subprocess.run([sys.executable, str(SCRIPT), "--root", str(self.root)],
                              input="n\n", text=True, capture_output=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(self.out.read_bytes(), b"original")
        self.assertIn("[Y/n]", proc.stdout)

    def test_cli_enter_overwrites_and_yes_is_noninteractive(self):
        self.out.write_bytes(b"original")
        proc = subprocess.run([sys.executable, str(SCRIPT), "--root", str(self.root)],
                              input="\n", text=True, capture_output=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(self._names(), {"README.md"})
        proc2 = subprocess.run([sys.executable, str(SCRIPT), "--root", str(self.root), "--yes"],
                               text=True, capture_output=True)
        self.assertEqual(proc2.returncode, 0, proc2.stderr)
        self.assertNotIn("[Y/n]", proc2.stdout)

    def test_cli_refuses_non_zip_destination(self):
        target = self.root / "do_not_overwrite.txt"
        target.write_bytes(b"valuable")
        proc = subprocess.run([sys.executable, str(SCRIPT), "--root", str(self.root),
                               "--output", str(target), "--yes"],
                              text=True, capture_output=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(target.read_bytes(), b"valuable")

    def test_unique_name_mode(self):
        a = mod._unique_filename(self.root)
        b = mod._unique_filename(self.root)
        self.assertNotEqual(a, b)
        self.assertTrue(a.name.startswith("routerFW_source_"))
        self.assertEqual(a.suffix, ".zip")

    def _inventory(self, archive=None):
        with zipfile.ZipFile(archive or self.out) as zf:
            return zf.read(mod.TREE_INDEX_NAME).decode("utf-8")

    def test_full_inventory_includes_all_six_heavy_dirs_by_name_only(self):
        for directory in ("firmware_output", ".git", "builds", "bck", "nw_test", "nl_test"):
            self._write(f"{directory}/sub/tree_visible.txt", "PRIVATE-CONTENT-DO-NOT-SHARE")
        self._write("keys/hidden.key", "PRIVATE-CONTENT-DO-NOT-SHARE")
        self._write("custom_files/a/private.env", "PRIVATE-CONTENT-DO-NOT-SHARE")
        mod.create_source_zip(self.root, self.out)
        inventory = self._inventory()
        for directory in ("firmware_output", ".git", "builds", "bck", "nw_test", "nl_test"):
            self.assertIn(f'{directory}/sub/tree_visible.txt', inventory)
        self.assertIn('keys/hidden.key', inventory)
        self.assertIn('custom_files/a/private.env', inventory)
        self.assertNotIn('PRIVATE-CONTENT-DO-NOT-SHARE', inventory)
        self.assertEqual(self._names(), {"README.md"})
        with zipfile.ZipFile(self.out) as zf:
            self.assertEqual(len(zf.namelist()), 2)

    def test_inventory_records_ordinary_files_and_exclusion_marker(self):
        self._write("docs/ru_док.md", "hello")
        self._write("secret/private_config.env", "not shared")
        mod.create_source_zip(self.root, self.out)
        inventory = self._inventory()
        self.assertIn('FILE+\t"README.md"', inventory)
        self.assertIn('FILE+\t"docs/ru_док.md"', inventory)
        self.assertIn('FILE-\t"secret/private_config.env"', inventory)
        self.assertIn('DIR\t"docs"', inventory)
        self.assertNotIn(str(self.root), inventory)

    def test_inventory_can_be_disabled_for_privacy(self):
        self._write("keys/private.pem", "private")
        mod.create_source_zip(self.root, self.out, include_tree=False)
        with zipfile.ZipFile(self.out) as zf:
            self.assertNotIn(mod.TREE_INDEX_NAME, zf.namelist())
            self.assertEqual(zf.namelist(), ["README.md"])

    def test_inventory_limit_fails_without_damaging_previous_archive(self):
        mod.create_source_zip(self.root, self.out)
        original = self.out.read_bytes()
        self._write("docs/a.md")
        with self.assertRaisesRegex(mod.SourcePackagingError, "лимит"):
            mod.create_source_zip(self.root, self.out, tree_max_entries=1)
        self.assertEqual(self.out.read_bytes(), original)
        self.assertEqual(list(self.root.glob(".*.tmp.zip")), [])

    def test_inventory_escapes_control_characters_on_every_platform(self):
        weird = "docs/odd\tname\n.txt"
        entry = Mock()
        entry.name = "odd\tname\n.txt"
        entry.path = str(self.root / weird)
        entry.is_symlink.return_value = False
        entry.is_dir.return_value = False
        entry.is_file.return_value = True
        with patch.object(mod.os, "scandir") as scan:
            scan.return_value.__enter__.return_value = [entry]
            lines = list(mod._iter_full_tree(self.root, {weird}, self.out, 10))
        self.assertEqual([line for line in lines if line.startswith("FILE+")],
                         ['FILE+\t"docs/odd\\tname\\n.txt"\n'])

    @unittest.skipIf(os.name == "nt", "Windows forbids control characters in filenames")
    def test_inventory_unusual_filename_has_unambiguous_escaped_line(self):
        weird = "docs/odd\tname\n.txt"
        self._write(weird)
        mod.create_source_zip(self.root, self.out)
        self.assertIn('FILE+\t"docs/odd\\tname\\n.txt"', self._inventory())

    def test_inventory_missing_subtree_fails_without_partial_publish(self):
        # Hard to emulate permissions on root CI; a failing generator ensures
        # errors propagate and the old archive is preserved transactionally.
        mod.create_source_zip(self.root, self.out)
        original = self.out.read_bytes()
        with patch.object(mod, "_iter_full_tree", side_effect=mod.SourcePackagingError("unreadable")):
            with self.assertRaises(mod.SourcePackagingError):
                mod.create_source_zip(self.root, self.out)
        self.assertEqual(self.out.read_bytes(), original)
        self.assertEqual(list(self.root.glob(".*.tmp.zip")), [])

    def test_batch_is_utf8_crlf_and_has_no_old_project_dependencies(self):
        batch = SCRIPT.with_suffix(".bat").read_bytes()
        self.assertEqual(batch.count(b"\n"), batch.count(b"\r\n"))
        self.assertFalse(batch.startswith(b"\xef\xbb\xbf"))
        text = batch.decode("utf-8").casefold()
        self.assertNotIn("szap_observed", text)
        self.assertNotIn("_observe_self.bat", text)
        self.assertIn("package_source_zip.py", text)
        self.assertIn("--root", text)


if __name__ == "__main__":
    unittest.main()
