"""Diff-bundle tree inventory regressions (Windows PowerShell runtime where available)."""
from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
import temp_support
SCRIPT = REPO / "scripts" / "write_worktree_tree.ps1"
BATCH = REPO / "capture_worktree_diff.bat"
SHELL = None
if sys.platform == "win32":
    SHELL = shutil.which("powershell.exe") or shutil.which("powershell") or shutil.which("pwsh")


class DiffTreeWiringTests(unittest.TestCase):
    def test_helper_is_wired_to_zip_before_compression(self):
        batch = BATCH.read_text(encoding="utf-8-sig")
        self.assertIn('set "TREE_INDEX=%OUT_DIR%\\WORKTREE_TREE.md"', batch)
        self.assertIn('scripts\\write_worktree_tree.ps1', batch)
        self.assertIn('if errorlevel 1 (', batch)
        self.assertIn('Compress-Archive -LiteralPath $items', batch)
        self.assertIn("$archive.GetEntry('WORKTREE_TREE.md')", batch)
        self.assertIn('WORKTREE_TREE.md: full path-only tree', batch)
        self.assertIn('except root .git', batch)
        self.assertLess(batch.index('write_worktree_tree.ps1'), batch.index('Compress-Archive'))
        self.assertIn('Write-Host (\'Архив для отправки:', batch)
        self.assertIn('Перезаписать предыдущий diff.zip? [Y/n]:', batch)

    def test_inventory_never_reads_file_payloads_or_follows_links(self):
        ps = SCRIPT.read_text(encoding="utf-8-sig")
        self.assertIn('GetFileSystemEntries', ps)
        self.assertIn('GetAttributes', ps)
        self.assertIn('StringComparer]::Ordinal', ps)
        self.assertIn('if ($isDirectory -and -not $isLink)', ps)
        self.assertNotIn('Get-Content', ps)
        self.assertNotIn('ReadAllBytes', ps)
        self.assertIn('exit 1', ps)


@unittest.skipUnless(SHELL, "Windows PowerShell is unavailable (the integration test runs on Windows CI)")
class DiffTreePowerShellRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="routerfw-tree-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "routerFW"
        self.root.mkdir()
        self.output = Path(self.tmp.name) / "WORKTREE_TREE.md"

    def add(self, name: str, data: bytes = b"INTERNAL_PRIVATE_PAYLOAD_NOT_FOR_TREE") -> None:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def run_tree(self, cap: int = 500000, root: Path | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            [SHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT),
             "-Root", str(root or self.root), "-Output", str(self.output), "-MaxEntries", str(cap)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=30,
            check=False,
        )

    def test_all_names_including_gitignored_and_generated_but_no_contents(self):
        self.add(".git/objects/ab/abcdef")
        self.add("firmware_output/huge-itb.bin", b"PRIVATE_FIRMWARE_CONTENT_MARKER")
        self.add("builds/image.tar.gz")
        self.add("bck/backup.zip")
        self.add("nw_test/result.txt")
        self.add("nl_test/result.txt")
        self.add("custom_files/private.conf", b"PRIVATE_CONFIG_CONTENT_MARKER")
        self.add("profiles/cmcc_rax3000me.conf")
        self.add("profiles/cmcc_rax3000m.conf")
        (self.root / "empty_dir").mkdir()
        result = self.run_tree()
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.output.read_text(encoding="utf-8-sig")
        for item in ("firmware_output/", "huge-itb.bin", "bck/", "nw_test/",
                     "nl_test/", "custom_files/", "private.conf", "empty_dir/", "profiles/"):
            self.assertIn(item, text)
        tree = text.split("```text\n", 1)[1].split("\n```", 1)[0]
        self.assertNotIn(".git", tree)
        self.assertNotIn("PRIVATE_FIRMWARE_CONTENT_MARKER", text)
        self.assertNotIn("PRIVATE_CONFIG_CONTENT_MARKER", text)
        self.assertLess(text.index("cmcc_rax3000m.conf"), text.index("cmcc_rax3000me.conf"))
        self.assertIn("Всего:", text)

    def test_repeat_is_deterministic(self):
        self.add("a/deep/file.md")
        self.add("b/other.py")
        first = self.run_tree()
        self.assertEqual(first.returncode, 0, first.stderr)
        body = self.output.read_bytes()
        second = self.run_tree()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(body, self.output.read_bytes())

    def test_entry_limit_fails_closed_and_deletes_partial_output(self):
        self.add("one.txt")
        self.add("two.txt")
        result = self.run_tree(cap=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.exists())

    def test_missing_root_fails_without_index(self):
        result = self.run_tree(root=self.root / "not-exists")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.exists())

    def test_directory_symlink_is_not_followed(self):
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        (outside / "private_outside.txt").write_text("SENSITIVE", encoding="utf-8")
        try:
            (self.root / "linked_dir").symlink_to(outside, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("Symlinks unavailable without developer privileges on this Windows host")
        result = self.run_tree()
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.output.read_text(encoding="utf-8-sig")
        self.assertIn("linked_dir/ [link: not traversed]", text)
        self.assertNotIn("private_outside.txt", text)


if __name__ == "__main__":
    unittest.main()
