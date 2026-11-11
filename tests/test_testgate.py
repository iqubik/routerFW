"""Small checks for testgate's summary and output classification."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "testgate.py"
SPEC = importlib.util.spec_from_file_location("routerfw_testgate", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
testgate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(testgate)


class TestgateTests(unittest.TestCase):
    def test_summary_parser_accepts_both_suite_labels_and_ansi(self):
        self.assertEqual(testgate.parse_summary(["=== Итого: 57 OK, 0 FAIL ==="]), (57, 0))
        self.assertEqual(testgate.parse_summary(["\x1b[32m=== Total: 50 OK, 2 FAIL ===\x1b[0m"]), (50, 2))

    def test_line_status_overrides_suite_color(self):
        self.assertEqual(testgate.line_color("[OK] Shell Syntax"), testgate.COLORS["ok"])
        self.assertEqual(testgate.line_color("[FAIL] Docker Smoke"), testgate.COLORS["fail"])
        self.assertIsNone(testgate.line_color("--- Check: Docker Smoke ---"))

    def test_duration_is_rendered_as_hours_minutes_seconds(self):
        self.assertEqual(testgate.format_duration(3661.4), "01:01:01")


if __name__ == "__main__":
    unittest.main()
