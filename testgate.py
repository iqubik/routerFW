#!/usr/bin/env python3
"""Run the Windows and WSL test suites side by side and archive their logs."""

from __future__ import annotations

from datetime import datetime
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import sys
import threading
import time


ROOT = Path(__file__).resolve().parent
WSL_DISTRO = os.environ.get("ROUTERFW_TESTGATE_WSL_DISTRO", "Debian")
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
SUMMARY_RE = re.compile(r"(?:Итого|Total):?\s*(\d+)\s+OK,\s*(\d+)\s+FAIL", re.IGNORECASE)
TIMING_RE = re.compile(r"^\[TIME\] (\d+) ms \| (.+)$")
COLORS = {
    "bat": "\x1b[36m",
    "wsl": "\x1b[35m",
    "ok": "\x1b[32m",
    "fail": "\x1b[31m",
    "warn": "\x1b[33m",
    "reset": "\x1b[0m",
}


def parse_summary(lines: list[str]) -> tuple[int, int] | None:
    for line in reversed(lines):
        match = SUMMARY_RE.search(ANSI_RE.sub("", line))
        if match:
            return int(match.group(1)), int(match.group(2))
    return None


def line_color(line: str) -> str | None:
    text = ANSI_RE.sub("", line).upper()
    if "[FAIL]" in text or "FAIL:" in text or "FAILED (" in text:
        return COLORS["fail"]
    if "[OK]" in text or "PASSED" in text or " OK," in text:
        return COLORS["ok"]
    if "[WARN]" in text or "[SKIP]" in text or "WARNING" in text:
        return COLORS["warn"]
    return None


def enable_ansi() -> bool:
    if not sys.stdout.isatty():
        return False
    if os.name != "nt":
        return True
    try:
        import ctypes

        handle = ctypes.windll.kernel32.GetStdHandle(-11)
        mode = ctypes.c_uint()
        if not ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            return False
        return bool(ctypes.windll.kernel32.SetConsoleMode(handle, mode.value | 0x0004))
    except (AttributeError, OSError):
        return False


def artifact_dir() -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base = ROOT / "artifacts" / "testgate" / stamp
    candidate = base
    suffix = 2
    while True:
        try:
            candidate.mkdir(parents=True, exist_ok=False)
            return candidate
        except FileExistsError:
            candidate = Path(f"{base}_{suffix:02d}")
            suffix += 1


def wsl_repo_path() -> str:
    result = subprocess.run(
        ["wsl.exe", "--distribution", WSL_DISTRO, "--exec", "wslpath", "-a", str(ROOT)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(detail or f"wslpath exited with {result.returncode}")
    return result.stdout.strip()


def start_suite(command: list[str]) -> subprocess.Popen[str]:
    return subprocess.Popen(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )


def stream_suite(
    name: str,
    process: subprocess.Popen[str],
    events: queue.Queue[tuple[str, str | None]],
) -> None:
    assert process.stdout is not None
    for line in process.stdout:
        events.put((name, line))
    events.put((name, None))


def wait_suite(
    name: str,
    process: subprocess.Popen[str],
    started: float,
    finished: dict[str, tuple[int, float]],
) -> None:
    code = process.wait()
    finished[name] = code, time.perf_counter() - started


def slowest_tests(timings: list[tuple[int, str, str]]) -> list[str]:
    return [
        f"{milliseconds / 1000:.3f} s | {suite.upper()} | {label}"
        for milliseconds, suite, label in sorted(timings, key=lambda row: -row[0])[:5]
    ]


def emit(name: str, line: str, *, ansi: bool) -> str:
    text = ANSI_RE.sub("", line.rstrip("\r\n"))
    suite_color = COLORS[name]
    status_color = line_color(text)
    color = status_color or suite_color
    if ansi:
        print(f"{color}[{name.upper()}] {text}{COLORS['reset']}", flush=True)
    else:
        print(f"[{name.upper()}] {text}", flush=True)
    return text


def save_summary(
    directory: Path,
    results: dict[str, tuple[int, tuple[int, int] | None]],
    elapsed: dict[str, float],
    total_elapsed: float,
    distro_error: str | None,
    slowest: list[str],
) -> bool:
    lines = [
        f"# Testgate — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "",
        f"WSL distribution: `{WSL_DISTRO}`",
        "",
        "| Набор | Exit code | OK | FAIL | Время |",
        "|---|---:|---:|---:|---:|",
    ]
    all_ok = True
    for name in ("bat", "wsl"):
        code, summary = results[name]
        counts = summary if summary is not None else ("—", "—")
        lines.append(f"| `{name}` | {code} | {counts[0]} | {counts[1]} | {format_duration(elapsed[name])} |")
        all_ok &= code == 0 and summary is not None and summary[1] == 0
    if distro_error:
        lines.extend(["", "WSL startup error:", "", f"```text\n{distro_error}\n```"])
    if slowest:
        lines.extend(["", "### Самые долгие проверки", "", *(f"- {line}" for line in slowest)])
    lines.extend([
        "",
        f"Total elapsed: **{format_duration(total_elapsed)}**",
        f"Result: **{'PASS' if all_ok else 'FAIL'}**",
        "",
    ])
    (directory / "summary.md").write_text("\n".join(lines), encoding="utf-8")
    return all_ok


def format_duration(seconds: float) -> str:
    total, milliseconds = divmod(max(0, round(seconds * 1000)), 1000)
    hours, remainder = divmod(total, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}.{milliseconds:03d}"


def main() -> int:
    ansi = enable_ansi()
    artifacts = artifact_dir()
    print(f"Testgate logs: {artifacts}", flush=True)
    gate_started = time.perf_counter()

    results: dict[str, tuple[int, tuple[int, int] | None]] = {}
    elapsed = {"bat": 0.0, "wsl": 0.0}
    started: dict[str, float] = {}
    processes: dict[str, subprocess.Popen[str]] = {}
    finished: dict[str, tuple[int, float]] = {}
    waiters: list[threading.Thread] = []
    timings: list[tuple[int, str, str]] = []
    tails: dict[str, list[str]] = {"bat": [], "wsl": []}
    log_handles = {
        "bat": (artifacts / "tester.bat.md").open("w", encoding="utf-8", newline=""),
        "wsl": (artifacts / "tester.sh.md").open("w", encoding="utf-8", newline=""),
    }
    native_logs = {
        "bat": (ROOT / "tester_log_win.md", artifacts / "tester.bat.md"),
        "wsl": (ROOT / "tester_log_lin.md", artifacts / "tester.sh.md"),
    }
    native_log_mtimes = {
        name: source.stat().st_mtime_ns if source.is_file() else None
        for name, (source, _) in native_logs.items()
    }
    distro_error = None

    def launch(name: str, command: list[str]) -> None:
        started[name] = time.perf_counter()
        process = processes[name] = start_suite(command)
        waiter = threading.Thread(
            target=wait_suite, args=(name, process, started[name], finished), daemon=True,
        )
        waiter.start()
        waiters.append(waiter)

    try:
        try:
            linux_root = wsl_repo_path()
            wsl_command = [
                "wsl.exe", "--distribution", WSL_DISTRO, "--exec", "bash", "-lc",
                'cd -- "$1" && exec bash ./tester.sh', "testgate", linux_root,
            ]
            launch("wsl", wsl_command)
            print(f"{COLORS['wsl'] if ansi else ''}[WSL] Запущен tester.sh в {WSL_DISTRO}{COLORS['reset'] if ansi else ''}", flush=True)
        except (OSError, RuntimeError) as error:
            distro_error = str(error)
            results["wsl"] = (1, None)
            message = f"[WSL] Не удалось запустить tester.sh: {distro_error}\n"
            log_handles["wsl"].write(message)
            log_handles["wsl"].flush()
            print(f"{COLORS['fail'] if ansi else ''}{message.rstrip()}{COLORS['reset'] if ansi else ''}", flush=True)

        try:
            launch("bat", ["cmd.exe", "/d", "/c", "call", "tester.bat"])
            print(f"{COLORS['bat'] if ansi else ''}[BAT] Запущен tester.bat{COLORS['reset'] if ansi else ''}", flush=True)
        except OSError as error:
            results["bat"] = (1, None)
            message = f"[BAT] Не удалось запустить tester.bat: {error}\n"
            log_handles["bat"].write(message)
            log_handles["bat"].flush()
            print(f"{COLORS['fail'] if ansi else ''}{message.rstrip()}{COLORS['reset'] if ansi else ''}", flush=True)

        events: queue.Queue[tuple[str, str | None]] = queue.Queue()
        threads = [
            threading.Thread(target=stream_suite, args=(name, process, events), daemon=True)
            for name, process in processes.items()
        ]
        for thread in threads:
            thread.start()

        active = set(processes)
        while active:
            try:
                name, line = events.get(timeout=0.2)
            except queue.Empty:
                continue
            if line is None:
                active.discard(name)
                continue
            clean = emit(name, line, ansi=ansi)
            if match := TIMING_RE.fullmatch(clean):
                timings.append((int(match[1]), name, match[2].rstrip()))
            log_handles[name].write(line)
            log_handles[name].flush()
            tails[name].append(clean)
            if len(tails[name]) > 250:
                del tails[name][0]

        for waiter in waiters:
            waiter.join()
        for name, (code, duration) in finished.items():
            results[name] = (code, parse_summary(tails[name]))
            elapsed[name] = duration
    except KeyboardInterrupt:
        for process in processes.values():
            if process.poll() is None:
                process.terminate()
        for process in processes.values():
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for name, process in processes.items():
            elapsed[name] = finished.get(name, (0, time.perf_counter() - started[name]))[1]
            results[name] = (process.returncode or 1, parse_summary(tails[name]))
        print("\n[WARN] Testgate остановлен пользователем; частичные логи сохранены.", flush=True)
        return_code = 130
    finally:
        for handle in log_handles.values():
            handle.close()

    for name, (source, target) in native_logs.items():
        if source.is_file() and source.stat().st_mtime_ns != native_log_mtimes[name]:
            shutil.copy2(source, target)

    total_elapsed = time.perf_counter() - gate_started
    slowest = slowest_tests(timings)
    if "return_code" in locals():
        all_ok = False
    else:
        all_ok = save_summary(artifacts, results, elapsed, total_elapsed, distro_error, slowest)
        return_code = 0 if all_ok else 1

    if slowest:
        print("Самые долгие проверки:", *slowest, sep="\n", flush=True)
    final_lines = []
    for name in ("bat", "wsl"):
        code, summary = results.get(name, (1, None))
        display = f"{summary[0]} OK / {summary[1]} FAIL" if summary else "сводка не найдена"
        color = COLORS["ok"] if code == 0 and summary and summary[1] == 0 else COLORS["fail"]
        final_lines.append((
            color if ansi else "",
            f"[{name.upper()}] exit={code}; {display}; время {format_duration(elapsed[name])}",
            COLORS["reset"] if ansi else "",
        ))
    final_lines.append((
        COLORS["ok"] if all_ok and ansi else (COLORS["fail"] if ansi else ""),
        f"{'PASS' if all_ok else 'FAIL'} — общее время {format_duration(total_elapsed)}; логи: {artifacts}",
        COLORS["reset"] if ansi else "",
    ))
    for prefix, message, suffix in final_lines:
        print(f"{prefix}{message}{suffix}", flush=True)
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
