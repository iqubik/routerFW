"""Small checks for testgate's summary and output classification."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch


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

    def test_duration_keeps_milliseconds_and_rolls_over(self):
        self.assertEqual(testgate.format_duration(3661.4), "01:01:01.400")
        self.assertEqual(testgate.format_duration(59.9996), "00:01:00.000")

    def test_suite_exit_records_its_own_elapsed_time(self):
        finished = {}
        with patch.object(testgate.time, "perf_counter", side_effect=[13.5, 21.0]):
            testgate.wait_suite("wsl", Mock(wait=lambda: 0), 10.0, finished)
            testgate.wait_suite("bat", Mock(wait=lambda: 1), 11.0, finished)
        self.assertEqual(finished, {"wsl": (0, 3.5), "bat": (1, 10.0)})

    def test_slowest_checks_are_ranked_across_suites(self):
        timings = [(ms, "bat", "a") for ms in range(1, 7)]
        timings.append((1100, "wsl", "check with spaces"))
        top = testgate.slowest_tests(timings)
        self.assertEqual(len(top), 5)
        self.assertEqual(top[0], "1.100 s | WSL | check with spaces")
        self.assertEqual(top[-1], "0.003 s | BAT | a")


if __name__ == "__main__":
    unittest.main()
