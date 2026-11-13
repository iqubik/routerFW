#!/usr/bin/env python3
"""Read-only firmware artifact checks and build-input snapshot support."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = "routerfw-build-snapshot.json"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_hash(path):
    digest = hashlib.sha256()
    if not path.exists():
        return digest.hexdigest()
    for item in sorted(path.rglob("*"), key=lambda p: p.relative_to(path).as_posix()):
        rel = item.relative_to(path).as_posix()
        if item.is_symlink():
            record = f"L\0{rel}\0{os.readlink(item)}\0"
            digest.update(record.encode())
        elif item.is_file():
            digest.update(f"F\0{rel}\0{sha256(item)}\0".encode())
        elif item.is_dir():
            digest.update(f"D\0{rel}\0".encode())
    return digest.hexdigest()


def profile_values(path):
    """Read only simple profile assignments; never source/evaluate profile text."""
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        match = re.match(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
        if not match:
            continue
        key, value = match.groups()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key] = value
    return values


def profile_packages(values):
    raw = values.get("SRC_PACKAGES", values.get("IMAGE_PKGS", values.get("PKGS", "")))
    for _ in range(4):
        raw = re.sub(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?",
                     lambda match: values.get(match.group(1), match.group(0)), raw)
    words = raw.split()
    return ({word for word in words if not word.startswith("-")},
            {word[1:] for word in words if word.startswith("-") and len(word) > 1})


def capture(profile, profile_id, inputs, destination):
    input_hashes = {}
    for value in inputs:
        label, raw_path = value.split("=", 1)
        input_hashes[label] = tree_hash(Path(raw_path))
    snapshot = {
        "schema": 1,
        "profile_id": profile_id,
        "profile_sha256": sha256(profile),
        "inputs": input_hashes,
    }
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def finalize(capture_file, output, mode, config):
    snapshot = json.loads(capture_file.read_text(encoding="utf-8"))
    snapshot.update({"mode": mode, "config_sha256": sha256(config) if config and config.is_file() else None})
    (output / SNAPSHOT).write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    checksums = output / "sha256sums"
    upstream = output / ".routerfw-upstream.sha256sums"
    if checksums.is_file() and not upstream.exists():
        checksums.replace(upstream)
    entries = [path for path in output.rglob("*")
               if path.is_file() and path != checksums]
    checksums.write_text("".join(
        f"{sha256(path)} *{path.relative_to(output).as_posix()}\n"
        for path in sorted(entries, key=lambda item: item.relative_to(output).as_posix())
    ), encoding="utf-8")


def verify(output, profile_id):
    checks = []
    def add(name, ok, detail):
        checks.append((name, ok, detail))

    sums = output / "sha256sums"
    if not sums.is_file():
        add("sha256sums", False, "missing checksum manifest")
    else:
        errors = []
        covered = set()
        for line in sums.read_text(encoding="utf-8", errors="replace").splitlines():
            match = re.fullmatch(r"([0-9a-fA-F]{64}) [ *](.+)", line)
            if not match:
                errors.append("malformed checksum entry")
                continue
            expected, name = match.groups()
            target = (output / name).resolve()
            if output.resolve() not in target.parents or not target.is_file():
                errors.append(f"missing/unsafe: {name}")
            elif sha256(target).lower() != expected.lower():
                errors.append(f"hash mismatch: {name}")
            else:
                covered.add(Path(name).as_posix())
        actual = {path.relative_to(output).as_posix() for path in output.rglob("*")
                  if path.is_file() and path != sums}
        absent = sorted(actual - covered)
        if absent:
            errors.append(f"not covered: {', '.join(absent)}")
        add("SHA256 manifest", not errors, "; ".join(errors) if errors else "all entries match")

    profiles_json = output / "profiles.json"
    selected = None
    if profiles_json.is_file():
        try:
            metadata = json.loads(profiles_json.read_text(encoding="utf-8"))
            profile = ROOT / "profiles" / f"{profile_id}.conf" if profile_id else None
            target_id = profile_values(profile).get("TARGET_PROFILE") if profile and profile.is_file() else None
            available = metadata.get("profiles") if isinstance(metadata, dict) else None
            if not isinstance(available, dict):
                raise ValueError("profiles.json must contain a profiles object")
            # An explicit profile must never silently validate an unrelated entry.
            if profile_id:
                selected = next((name for name in (target_id, profile_id)
                                 if name and name in available), None)
            else:
                selected = next(iter(available), None)
            if selected is None:
                expected = target_id or profile_id or "an image profile"
                add("profiles.json images", False,
                    f"profile {expected!r} is absent; available={sorted(available)}")
            else:
                target = available[selected]
                if not isinstance(target, dict):
                    raise ValueError(f"profiles.json profile {selected!r} must be an object")
                images = target.get("images", [])
                if not isinstance(images, list):
                    raise ValueError(f"profiles.json images for {selected!r} must be an array")
                errors = []
                for image in images:
                    if not isinstance(image, dict):
                        errors.append("malformed image metadata")
                        continue
                    name = image.get("name")
                    if not isinstance(name, str) or not name or Path(name).name != name:
                        errors.append(f"unsafe image name: {name!r}")
                        continue
                    path = output / name
                    if not path.is_file():
                        errors.append(f"missing image: {name}")
                    elif path.stat().st_size != image.get("size") or sha256(path) != image.get("sha256"):
                        errors.append(f"size/hash differs: {name}")
                add("profiles.json images", bool(images) and not errors,
                    "; ".join(errors) if errors else f"{selected}: {len(images)} images present and match")
        except (ValueError, OSError, TypeError, AttributeError) as error:
            add("profiles.json", False, str(error))
    else:
        add("profiles.json", False, "missing")

    manifests = list(output.glob("*.manifest"))
    if manifests:
        manifest_lines = [line for line in manifests[0].read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]
        entries = len(manifest_lines)
        add("package manifest", entries > 0, f"{manifests[0].name}: {entries} package entries")
        if profile_id:
            profile_file = ROOT / "profiles" / f"{profile_id}.conf"
            installed = {line.partition(" - ")[0].strip() for line in manifest_lines}
            expected, excluded = profile_packages(profile_values(profile_file)) if profile_file.is_file() else (set(), set())
            aliases = {"libgcc": ("libgcc1",), "libustream-mbedtls": ("libustream-mbedtls20201210",),
                       "nftables": ("nftables-json",)}
            resolved = {name for name in expected if name in installed or any(alias in installed for alias in aliases.get(name, ()))}
            missing, unexpected = expected - resolved, excluded & installed
            add("profile packages", not missing and not unexpected,
                f"missing={sorted(missing)} excluded-but-present={sorted(unexpected)}" if missing or unexpected
                else f"all {len(expected)} requested packages present; exclusions absent")
    else:
        add("package manifest", False, "no *.manifest file")

    snapshot_file = output / SNAPSHOT
    if not snapshot_file.is_file():
        add("build snapshot", False, "missing; available on builds made with this validator")
    else:
        try:
            snapshot = json.loads(snapshot_file.read_text(encoding="utf-8"))
            add("snapshot profile", profile_id is None or snapshot.get("profile_id") == profile_id,
                f"built with {snapshot.get('profile_id')}")
            if profile_id:
                profile = ROOT / "profiles" / f"{profile_id}.conf"
                current_hash = sha256(profile) if profile.is_file() else "missing"
                add("current profile", snapshot.get("profile_sha256") == current_hash,
                    "matches build-time profile" if snapshot.get("profile_sha256") == current_hash else "profile changed since build")
                for label in ("custom_files", "custom_patches", "src_packages", "custom_packages"):
                    if label not in snapshot.get("inputs", {}):
                        continue
                    current_tree = tree_hash(ROOT / label / profile_id)
                    matches = snapshot["inputs"][label] == current_tree
                    add(f"current {label}", matches,
                        "matches build-time inputs" if matches else "input files changed since build")
            config_name = "config.buildinfo" if (output / "config.buildinfo").is_file() else "build.config"
            config = output / config_name
            expected = snapshot.get("config_sha256")
            # Missing config hash is unverifiable, not a successful check.
            config_ok = (isinstance(expected, str)
                         and re.fullmatch(r"[0-9a-fA-F]{64}", expected) is not None
                         and config.is_file() and sha256(config).lower() == expected.lower())
            add("build config snapshot", config_ok,
                f"{config_name}: " + ("matches" if config_ok else "hash missing or config differs"))
        except (ValueError, OSError) as error:
            add("build snapshot", False, str(error))
    if profile_id:
        profile = ROOT / "profiles" / f"{profile_id}.conf"
        config = output / ("config.buildinfo" if (output / "config.buildinfo").is_file() else "build.config")
        if profile.is_file() and config.is_file():
            expected_options = dict(re.findall(
                r"(?m)^\s*(CONFIG_[A-Za-z0-9_]+)=(.*)$",
                profile.read_text(encoding="utf-8-sig"),
            ))
            expected_options = {key: (value[:-1] if value.endswith("'") else value)
                                for key, value in expected_options.items()}
            actual_options = dict(re.findall(
                r"(?m)^\s*(CONFIG_[A-Za-z0-9_]+)=(.*)$",
                config.read_text(encoding="utf-8", errors="replace"),
            ))
            differences = [key for key, value in expected_options.items()
                           if actual_options.get(key) != value]
            add("profile build options", not differences,
                "all explicitly declared CONFIG options match" if not differences
                else f"missing/different: {', '.join(differences)}")
    return checks


def outputs():
    paths = []
    for mode in ("imagebuilder", "sourcebuilder"):
        base = ROOT / "firmware_output" / mode
        if base.is_dir():
            paths.extend(p for p in base.glob("*/*") if p.is_dir())
    return sorted(paths, key=lambda p: p.stat().st_mtime, reverse=True)


def menu():
    choices = outputs()
    if not choices:
        raise ValueError("firmware_output has no build directories")
    for index, path in enumerate(choices, 1):
        print(f"{index:2}. {path.relative_to(ROOT)}")
    choice = input("Артефакт # (Enter — самый новый): ").strip()
    output = choices[int(choice) - 1] if choice else choices[0]
    profiles = sorted((ROOT / "profiles").glob("*.conf"))
    for index, path in enumerate(profiles, 1):
        print(f"{index:2}. {path.stem}")
    choice = input("Профиль # (Enter — без сравнения текущего профиля): ").strip()
    profile_id = profiles[int(choice) - 1].stem if choice else None
    return output, profile_id


def main():
    if len(sys.argv) > 1 and sys.argv[1] in {"capture", "finalize"}:
        command = sys.argv.pop(1)
        internal = argparse.ArgumentParser()
        if command == "capture":
            internal.add_argument("--profile", type=Path, required=True)
            internal.add_argument("--profile-id", required=True)
            internal.add_argument("--input", action="append", default=[])
            internal.add_argument("--file", type=Path, required=True)
            args = internal.parse_args()
            capture(args.profile, args.profile_id, args.input, args.file)
        else:
            internal.add_argument("--file", type=Path, required=True)
            internal.add_argument("--output", type=Path, required=True)
            internal.add_argument("--mode", required=True)
            internal.add_argument("--config", type=Path)
            args = internal.parse_args()
            finalize(args.file, args.output, args.mode, args.config)
        return 0

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", nargs="?", type=Path, help="build artifact directory")
    parser.add_argument("--profile", help="current profile id, e.g. cmcc_rax3000m_25126_ow_full")
    parser.add_argument("--json", action="store_true", help="emit machine-readable results")
    args = parser.parse_args()
    try:
        if args.output is None:
            output, profile_id = menu()
        else:
            output, profile_id = args.output, args.profile
            if not output.is_absolute():
                output = ROOT / output
        results = verify(output.resolve(), profile_id)
        if args.json:
            print(json.dumps([{"check": n, "ok": ok, "detail": d} for n, ok, d in results], indent=2))
        else:
            for name, ok, detail in results:
                print(f"{'PASS' if ok else 'FAIL'} | {name} | {detail}")
        return 0 if all(ok for _, ok, _ in results) else 1
    except (OSError, ValueError, IndexError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
