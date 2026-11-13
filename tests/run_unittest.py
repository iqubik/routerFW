#!/usr/bin/env python3
# file: tests/run_unittest.py
"""Run the Python checks with per-test timings on Python 3.10 and newer."""

from pathlib import Path
from time import perf_counter
import sys
import unittest

REPO = Path(__file__).resolve().parents[1]
(REPO / "tmp").mkdir(parents=True, exist_ok=True)
sys.dont_write_bytecode = True


class TimedResult(unittest.TextTestResult):
    def __init__(self, *args):
        super().__init__(*args)
        self.timings = []

    def startTest(self, test):
        super().startTest(test)
        self.started = perf_counter()

    def stopTest(self, test):
        milliseconds = round((perf_counter() - self.started) * 1000)
        self.timings.append((milliseconds, test.id()))
        self.stream.writeln(f"[UNIT TIME] {milliseconds} ms | {test.id()}")
        super().stopTest(test)


def main() -> int:
    suite = unittest.defaultTestLoader.discover(str(Path(__file__).resolve().parent))
    result = unittest.TextTestRunner(verbosity=0, resultclass=TimedResult).run(suite)
    print("Slowest Python tests (up to 5):")
    for milliseconds, name in sorted(result.timings, reverse=True)[:5]:
        print(f"[UNIT TOP] {milliseconds} ms | {name}")
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
