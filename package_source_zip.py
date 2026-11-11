#!/usr/bin/env python3
# file: package_source_zip.py
"""Export the routerFW source tree for review without firmware/build artefacts.

Standalone optional tool (Python >=3.10); the routerFW builders do not require Python.
No Git index changes, no reads of excluded file contents and no private keys.
The optional directory inventory lists excluded paths by name (privacy warning).
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import re
import sys
import uuid
import zipfile
from datetime import datetime
from pathlib import Path

# Prune before recursion. The six explicitly requested heavy directories are
# included here along with generated/test/cache environments.
EXCLUDED_DIRS = frozenset({
    ".git", "firmware_output", "builds", "bck", "nw_test", "nl_test",
    "artifacts", ".docker_tmp", "tmp_test_runtime", "temp_packer_sh",
    "tmp", "output", "dist", "build", "coverage", "__pycache__",
    ".venv", "venv", ".tox", ".pytest_cache", ".mypy_cache",
    ".ruff_cache", ".cache", ".idea", ".vscode", "node_modules",
    "reverse", "temp", ".tmp",
})
# These are build-customization/user-data trees, not the routerFW core source.
# Opt-in is possible, but key material and local secrets are ALWAYS excluded.
CUSTOM_DIRS = frozenset({
    "custom_files", "custom_packages", "custom_patches", "src_packages",
})
SECRET_DIRS = frozenset({
    "keys", ".ssh", ".gnupg", ".aws", ".azure", ".kube",
})
SECRET_FILENAMES = frozenset({
    "id_rsa", "id_ed25519", "id_ecdsa", "id_dsa", "credentials.json",
})
SECRET_SUFFIXES = frozenset({
    ".pem", ".key", ".p12", ".pfx", ".kdbx",
})
SAFE_DOTENV_NAMES = frozenset({
    ".env.example", ".env.sample", ".env.template",
})
# Generated distributables/firmware and archives are not source. In particular
# this excludes the resulting routerFW_source.zip on a subsequent run.
ARTIFACT_SUFFIXES = frozenset({
    ".zip", ".7z", ".rar", ".jpa", ".jps", ".gz", ".xz", ".zst",
    ".bz2", ".tgz", ".tar", ".iso", ".vhdx", ".qcow2", ".img",
    ".bin", ".ipk", ".apk", ".deb", ".rpm", ".o", ".obj",
    ".so", ".dll", ".exe", ".pyc", ".log", ".tmp",
})
# Generated root scripts and run logs; the actual _packer sources ARE included.
EXCLUDED_ROOT_FILES = frozenset({
    "_unpacker.sh", "_unpacker.bat", "debug.md", "active.diff.patch",
})
TRASH_FILES = frozenset({"thumbs.db", "desktop.ini"})
PRIVATE_NAME_RE = re.compile(r"(?:^|[._-])(?:private|local|credentials|secrets?)(?:[._-]|$)", re.I)
GENERATED_DIR_RE = re.compile(r"^(?:temp_packer_|tester_tmp_|\.tmp_)", re.I)
GENERATED_FILE_RE = re.compile(r"^(?:tester_log_.*\.md|tester_tmp_.*|routerfw_(?:linux|win)dockerbuilder_.*)$", re.I)
DEFAULT_MAX_FILE_MIB = 4
TREE_INDEX_NAME = "SOURCE_TREE_INDEX.txt"
DEFAULT_TREE_MAX_ENTRIES = 250_000


class SourcePackagingError(RuntimeError):
    """Packaging failed; any existing output must remain untouched."""


def _is_secret_path(relative: Path) -> bool:
    parts = relative.parts
    if any(part.casefold() in SECRET_DIRS for part in parts[:-1]):
        return True
    name = relative.name.casefold()
    if name in SECRET_FILENAMES or relative.suffix.casefold() in SECRET_SUFFIXES:
        return True
    if (name == ".env" or name.startswith(".env.")) and name not in SAFE_DOTENV_NAMES:
        return True
    if name.startswith("~$"):
        return True
    return any(PRIVATE_NAME_RE.search(part) for part in parts)


def _skip_dir(name: str, relative: Path, include_custom: bool) -> bool:
    lower = name.casefold()
    if lower in EXCLUDED_DIRS or lower in SECRET_DIRS or GENERATED_DIR_RE.match(lower):
        return True
    if relative.as_posix().casefold() == "scripts/checker":
        return True
    if not include_custom and len(relative.parts) == 1 and lower in CUSTOM_DIRS:
        return True
    return _is_secret_path(relative / "placeholder")


def _skip_file(relative: Path, file_size: int, max_bytes: int) -> str | None:
    name = relative.name.casefold()
    if name in TRASH_FILES or (len(relative.parts) == 1 and name in EXCLUDED_ROOT_FILES) or GENERATED_FILE_RE.match(name):
        return "generated"
    if relative.suffix.casefold() in ARTIFACT_SUFFIXES:
        return "artifact"
    if _is_secret_path(relative):
        return "secret"
    if file_size > max_bytes:
        return "large"
    return None


def collect_source_files(root: Path, *, include_custom: bool = False,
                         max_file_mib: int = DEFAULT_MAX_FILE_MIB) -> tuple[list[Path], collections.Counter[str]]:
    """Collect files without entering excluded directories or following symlinks."""
    root = root.resolve()
    if not root.is_dir():
        raise SourcePackagingError(f"Корень routerFW не найден: {root}")
    if max_file_mib < 1:
        raise SourcePackagingError("--max-file-mib должен быть не меньше 1")

    max_bytes = max_file_mib * 1024 * 1024
    files: list[Path] = []
    skipped: collections.Counter[str] = collections.Counter()
    stack = [root]
    while stack:
        directory = stack.pop()
        try:
            with os.scandir(directory) as handle:
                entries = sorted(handle, key=lambda entry: (entry.name.casefold(), entry.name))
        except OSError as exc:
            raise SourcePackagingError(f"Ошибка чтения каталога {directory}: {exc}") from exc

        child_dirs: list[Path] = []
        for entry in entries:
            path = Path(entry.path)
            rel = path.relative_to(root)
            try:
                if entry.is_symlink():
                    skipped["symlink"] += 1
                    continue
                if entry.is_dir(follow_symlinks=False):
                    if _skip_dir(entry.name, rel, include_custom):
                        skipped["directory"] += 1
                    else:
                        child_dirs.append(path)
                elif entry.is_file(follow_symlinks=False):
                    reason = _skip_file(rel, entry.stat(follow_symlinks=False).st_size, max_bytes)
                    if reason:
                        skipped[reason] += 1
                    else:
                        files.append(path)
            except OSError as exc:
                raise SourcePackagingError(f"Ошибка проверки файла {rel}: {exc}") from exc
        stack.extend(reversed(child_dirs))

    files.sort(key=lambda p: (p.relative_to(root).as_posix().casefold(), p.relative_to(root).as_posix()))
    return files, skipped


def _iter_full_tree(root: Path, included: set[str], temporary: Path,
                    max_entries: int):
    """Stream all names in the project tree, including files excluded from the ZIP.

    Directory entries are enumerated, but excluded file *contents* are never opened.
    Symlinks are listed by name without following them. A finite entry limit protects
    the export from massive .git/build trees; hitting it fails rather than silently
    publishing an incomplete inventory.
    """
    if max_entries < 1:
        raise SourcePackagingError("--tree-max-entries должен быть не меньше 1")
    yield "# routerFW source-tree inventory (path names only; UTF-8; relative to repository root)\n"
    yield "# DIR=directory; FILE+=bytes included; FILE-=metadata only; LINK=symlink not followed\n"
    yield "# File names inside excluded/private trees are listed; their contents are NOT included.\n"
    yield "# WARNING: path names can also reveal confidential information. Review before sharing.\n"
    yield "# Generated during export; this index and the output ZIP are not source files.\n"
    count = 0
    stack = [root]
    while stack:
        directory = stack.pop()
        try:
            with os.scandir(directory) as scan:
                entries = sorted(scan, key=lambda entry: (entry.name.casefold(), entry.name))
        except OSError as exc:
            rel = directory.relative_to(root).as_posix()
            raise SourcePackagingError(
                f"Невозможно составить полное дерево, каталог недоступен: {rel}: {exc}. "
                "Для упаковки без перечня путей используйте --no-tree"
            ) from exc

        child_dirs = []
        for entry in entries:
            path = Path(entry.path)
            if path == temporary:
                # The archive currently being built is not part of the input snapshot.
                continue
            count += 1
            if count > max_entries:
                raise SourcePackagingError(
                    f"Полное дерево превысило лимит {max_entries} путей. "
                    "Увеличьте --tree-max-entries N или используйте --no-tree"
                )
            rel = path.relative_to(root).as_posix()
            try:
                if entry.is_symlink():
                    kind = "LINK"
                elif entry.is_dir(follow_symlinks=False):
                    kind = "DIR"
                    child_dirs.append(path)
                elif entry.is_file(follow_symlinks=False):
                    kind = "FILE+" if rel in included else "FILE-"
                else:
                    kind = "OTHER"
            except OSError as exc:
                raise SourcePackagingError(f"Невозможно прочитать тип пути {rel}: {exc}") from exc
            # JSON string escapes tabs/newlines in unusual names without losing Unicode.
            yield f"{kind}\t{json.dumps(rel, ensure_ascii=False)}\n"
        stack.extend(reversed(child_dirs))


def _verify_archive(archive: Path, expected: list[str]) -> None:
    """Check CRC, exact paths, count, duplicate names, and exclusion policy."""
    try:
        with zipfile.ZipFile(archive, "r") as zf:
            bad = zf.testzip()
            if bad:
                raise SourcePackagingError(f"Ошибка CRC ZIP: {bad}")
            actual = [info.filename for info in zf.infolist()]
    except (OSError, zipfile.BadZipFile) as exc:
        raise SourcePackagingError(f"ZIP не читается: {exc}") from exc

    if actual != expected or len(set(name.casefold() for name in actual)) != len(actual):
        raise SourcePackagingError("Содержимое ZIP не совпадает со списком исходных файлов")
    for name in actual:
        relative = Path(name)
        if name.startswith("/") or "\\" in name or ".." in relative.parts:
            raise SourcePackagingError(f"Небезопасный путь в ZIP: {name}")
        if any(part.casefold() in EXCLUDED_DIRS | SECRET_DIRS for part in relative.parts[:-1]):
            raise SourcePackagingError(f"Запрещённый каталог попал в ZIP: {name}")
        if _skip_file(relative, 0, 2**63) is not None:
            raise SourcePackagingError(f"Запрещённый файл попал в ZIP: {name}")


def create_source_zip(root: Path, archive: Path, *, include_custom: bool = False,
                      max_file_mib: int = DEFAULT_MAX_FILE_MIB,
                      include_tree: bool = True,
                      tree_max_entries: int = DEFAULT_TREE_MAX_ENTRIES) -> dict[str, object]:
    """Write/verify a temporary .zip, then atomically replace the final output."""
    root = root.resolve()
    archive = archive.resolve()
    files, skipped = collect_source_files(root, include_custom=include_custom, max_file_mib=max_file_mib)
    if not files:
        raise SourcePackagingError("Исходные файлы для упаковки не найдены")
    expected = [path.relative_to(root).as_posix() for path in files]
    if len({name.casefold() for name in expected}) != len(expected):
        raise SourcePackagingError("Обнаружены конфликтующие имена файлов (без учёта регистра)")
    if include_tree and TREE_INDEX_NAME.casefold() in {name.casefold() for name in expected}:
        raise SourcePackagingError(f"Зарезервированное имя файла: {TREE_INDEX_NAME}")
    if include_tree and tree_max_entries < 1:
        raise SourcePackagingError("--tree-max-entries должен быть не меньше 1")

    archive.parent.mkdir(parents=True, exist_ok=True)
    # The temporary file MUST have .zip extension. PowerShell/ZIP integrations
    # may reject an intermediate name ending in .new.
    temporary = archive.with_name(f".{archive.stem}.{uuid.uuid4().hex}.tmp.zip")
    total = sum(p.stat().st_size for p in files)
    print(f"[routerFW] Исходных файлов: {len(files)}, объём: {total / 1048576:.2f} MiB", flush=True)
    if include_custom:
        print("[WARN] --include-custom: проверьте пользовательские файлы на секреты перед отправкой!", flush=True)

    try:
        with zipfile.ZipFile(temporary, "x", compression=zipfile.ZIP_DEFLATED,
                             compresslevel=6, allowZip64=True) as zf:
            for path, name in zip(files, expected):
                try:
                    zf.write(path, arcname=name)
                except OSError as exc:
                    raise SourcePackagingError(f"Ошибка чтения {name}: {exc}") from exc
            if include_tree:
                with zf.open(TREE_INDEX_NAME, "w", force_zip64=True) as index:
                    for line in _iter_full_tree(root, set(expected), temporary, tree_max_entries):
                        index.write(line.encode("utf-8"))
        _verify_archive(temporary, expected + ([TREE_INDEX_NAME] if include_tree else []))
        os.replace(temporary, archive)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise

    print(f"[routerFW] ZIP CRC и список файлов: OK ({len(expected)} исходных файлов"
          f"{' + дерево путей' if include_tree else ''})", flush=True)
    if include_tree:
        print("[routerFW] SOURCE_TREE_INDEX.txt: полное дерево имён, включая исключённые файлы ",
              "(без их содержимого)", sep="", flush=True)
        print("[WARN] Имена приватных файлов тоже могут быть конфиденциальными; "
              "проверьте SOURCE_TREE_INDEX.txt перед отправкой.", flush=True)
    print("[routerFW] Пропущено: " + (", ".join(f"{k}={v}" for k, v in sorted(skipped.items())) or "нет"), flush=True)
    if skipped["large"]:
        print(f"[WARN] {skipped['large']} крупных файлов пропущено (лимит {max_file_mib} MiB на файл). "
              "При необходимости используйте --max-file-mib N.", flush=True)
    return {"archive": archive, "files": len(expected), "bytes": archive.stat().st_size,
            "tree": include_tree, "skipped": dict(skipped)}


def _ask_overwrite(archive: Path) -> bool:
    while True:
        try:
            answer = input(f'[WARN] Уже существует "{archive}".\nПерезаписать предыдущий ZIP? [Y/n]: ').strip().casefold()
        except EOFError as exc:
            raise SourcePackagingError("Нет интерактивного ввода; используйте --yes") from exc
        if answer in ("", "y", "yes", "д", "да"):
            return True
        if answer in ("n", "no", "н", "нет"):
            return False
        print("Введите Y или N (Enter = Y).")


def _print_green_archive(archive: Path) -> None:
    message = f"Архив для отправки: {archive}"
    if os.name == "nt" and sys.stdout.isatty():
        # Windows Console API supports colour even with VT sequences disabled.
        try:
            import ctypes
            from ctypes import wintypes

            class COORD(ctypes.Structure):
                _fields_ = [("X", wintypes.SHORT), ("Y", wintypes.SHORT)]

            class SMALL_RECT(ctypes.Structure):
                _fields_ = [("Left", wintypes.SHORT), ("Top", wintypes.SHORT),
                            ("Right", wintypes.SHORT), ("Bottom", wintypes.SHORT)]

            class CONSOLE_SCREEN_BUFFER_INFO(ctypes.Structure):
                _fields_ = [("dwSize", COORD), ("dwCursorPosition", COORD),
                            ("wAttributes", wintypes.WORD), ("srWindow", SMALL_RECT),
                            ("dwMaximumWindowSize", COORD)]

            k32 = ctypes.windll.kernel32
            handle = k32.GetStdHandle(-11)
            info = CONSOLE_SCREEN_BUFFER_INFO()
            if k32.GetConsoleScreenBufferInfo(handle, ctypes.byref(info)):
                old = info.wAttributes
                try:
                    k32.SetConsoleTextAttribute(handle, 0x0A)
                    print(message, flush=True)
                finally:
                    k32.SetConsoleTextAttribute(handle, old)
                return
        except (OSError, AttributeError):
            pass
    if sys.stdout.isatty():
        print(f"\x1b[92m{message}\x1b[0m", flush=True)
    else:
        print(message, flush=True)


def _unique_filename(root: Path) -> Path:
    suffix = datetime.now().strftime("%Y%m%d_%H%M%S")
    return root / f"routerFW_source_{suffix}_{uuid.uuid4().hex[:6]}.zip"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="routerFW: ZIP с исходниками без build-артефактов")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent,
                        help="Корень репозитория (по умолчанию — папка скрипта)")
    parser.add_argument("--output", type=Path, help="Имя выходного ZIP (по умолчанию routerFW_source.zip)")
    parser.add_argument("--unique", action="store_true", help="Уникальное имя ZIP с датой и идентификатором")
    parser.add_argument("--include-custom", action="store_true",
                        help="Явно включить custom_files/custom_packages/custom_patches/src_packages")
    parser.add_argument("--max-file-mib", type=int, default=DEFAULT_MAX_FILE_MIB,
                        help="Предел на один файл в MiB (по умолчанию 4)")
    parser.add_argument("--yes", "-y", action="store_true", help="Перезаписать существующий ZIP без вопроса")
    parser.add_argument("--no-tree", action="store_true",
                        help="Не включать полный список путей (если важна приватность имён или скорость)")
    parser.add_argument("--tree-max-entries", type=int, default=DEFAULT_TREE_MAX_ENTRIES,
                        help=f"Максимум путей в полном дереве, по умолчанию {DEFAULT_TREE_MAX_ENTRIES}")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    if args.output and args.unique:
        parser.error("--output и --unique нельзя использовать вместе")
    output = args.output.resolve() if args.output else (_unique_filename(root) if args.unique else root / "routerFW_source.zip")
    if output.suffix.casefold() != ".zip":
        parser.error("--output должен иметь расширение .zip")

    try:
        if output.exists() and not args.yes and not _ask_overwrite(output):
            print("[INFO] Отменено. Старый архив сохранён.", flush=True)
            return 0
        result = create_source_zip(root, output, include_custom=args.include_custom,
                                   max_file_mib=args.max_file_mib,
                                   include_tree=not args.no_tree,
                                   tree_max_entries=args.tree_max_entries)
    except (SourcePackagingError, OSError, zipfile.BadZipFile) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr, flush=True)
        return 1

    print(f"[routerFW] Размер ZIP: {result['bytes'] / 1048576:.2f} MiB", flush=True)
    _print_green_archive(output)
    print("[WARN] Перед отправкой проверьте ZIP на приватные данные в профилях и документах.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
