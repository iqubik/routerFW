"""Offline regression for firmware artifact validation."""

import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import subprocess
import tempfile
import unittest
from unittest import mock

import temp_support
sys.dont_write_bytecode = True

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "validate_build.py"
SPEC = importlib.util.spec_from_file_location("routerfw_validate_build", SCRIPT)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


class FirmwareValidationTests(unittest.TestCase):
    def test_both_build_modes_publish_snapshot_support(self):
        root = Path(__file__).resolve().parents[1]
        for compose in ("docker-compose.yaml", "docker-compose-src.yaml"):
            text = (root / "system" / compose).read_text(encoding="utf-8")
            self.assertNotIn("validate_build.py", text)
        for script in ("ib_builder.sh", "src_builder.sh"):
            text = (root / "system" / script).read_text(encoding="utf-8")
            self.assertIn("snapshot_runtime capture", text)
            self.assertIn("snapshot_runtime finalize", text)
        self.assertNotIn("scripts/validate_build.py", (root / "_packer.sh").read_text(encoding="utf-8"))
        self.assertNotIn("scripts/validate_build.py", (root / "_packer.bat").read_text(encoding="utf-8-sig"))

    def test_container_snapshot_runtime_is_embedded_in_builders(self):
        root = Path(__file__).resolve().parents[1]
        pattern = re.compile(
            r"snapshot_runtime\(\) \{\r?\npython3 -B - \"\$@\" "
            r"<<'PY_ROUTERFW_SNAPSHOT'\r?\n(.*?)\r?\nPY_ROUTERFW_SNAPSHOT\r?\n\}",
            re.DOTALL,
        )
        for name, mode in (("ib_builder.sh", "imagebuilder"),
                           ("src_builder.sh", "sourcebuilder")):
            with self.subTest(builder=name), tempfile.TemporaryDirectory(prefix="routerfw-runtime-") as scratch:
                work = Path(scratch)
                source = (root / "system" / name).read_text(encoding="utf-8")
                match = pattern.search(source)
                self.assertIsNotNone(match, name)
                helper = work / "snapshot_runtime.py"
                helper.write_text(match.group(1) + "\n", encoding="utf-8")
                profile = work / "profile.conf"
                profile.write_text('PROFILE_NAME="demo"\n', encoding="utf-8")
                inputs = work / "custom_files"
                inputs.mkdir()
                (inputs / "probe.txt").write_text("fixture\n", encoding="utf-8")
                output = work / "artifacts"
                output.mkdir()
                image = output / "demo.bin"
                image.write_bytes(b"firmware")
                config = output / "config.buildinfo"
                config.write_text("CONFIG_CCACHE=y\n", encoding="utf-8")
                manifest = output / "demo.manifest"
                manifest.write_text("base-files - 1\n", encoding="utf-8")
                profiles = output / "profiles.json"
                profiles.write_text(json.dumps({"profiles": {"demo": {"images": [{
                    "name": image.name, "sha256": hashlib.sha256(image.read_bytes()).hexdigest(),
                    "size": image.stat().st_size,
                }]}}}), encoding="utf-8")
                checksums = output / "sha256sums"
                checksums.write_text("upstream checksum list\n", encoding="utf-8")
                capture = work / "capture.json"
                base = [sys.executable, "-B", str(helper)]
                result = subprocess.run(
                    base + ["capture", str(profile), "demo", str(capture),
                            f"custom_files={inputs}"], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                result = subprocess.run(
                    base + ["finalize", str(capture), str(output), mode, str(config)],
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                snapshot = json.loads((output / validator.SNAPSHOT).read_text(encoding="utf-8"))
                self.assertEqual(snapshot["mode"], mode)
                self.assertEqual(snapshot["inputs"]["custom_files"], validator.tree_hash(inputs))
                results = validator.verify(output, None)
                self.assertTrue(all(ok for _, ok, _ in results), results)
                self.assertTrue((output / ".routerfw-upstream.sha256sums").is_file())

    def test_checks_manifest_profiles_and_image_bytes(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-validate-") as scratch:
            output = Path(scratch) / "artifacts"
            output.mkdir()
            image = output / "demo.bin"
            image.write_bytes(b"firmware")
            digest = hashlib.sha256(image.read_bytes()).hexdigest()
            (output / "config.buildinfo").write_text("CONFIG_CCACHE=y\n", encoding="utf-8")
            (output / "profiles.json").write_text(json.dumps({
                "profiles": {"demo": {"images": [{"name": image.name,
                                                       "sha256": digest,
                                                       "size": image.stat().st_size}]}}
            }), encoding="utf-8")
            (output / "demo.manifest").write_text("base-files - 1\n", encoding="utf-8")
            (output / "sha256sums").write_text(
                f"{digest} *{image.name}\n"
                f"{hashlib.sha256((output / 'profiles.json').read_bytes()).hexdigest()} *profiles.json\n"
                f"{hashlib.sha256((output / 'demo.manifest').read_bytes()).hexdigest()} *demo.manifest\n",
                encoding="utf-8",
            )
            profile = Path(scratch) / "profile.conf"
            profile.write_text('PROFILE_NAME="demo"\n', encoding="utf-8")
            capture = Path(scratch) / "capture.json"
            validator.capture(profile, "demo", [], capture)
            validator.finalize(capture, output, "sourcebuilder", output / "config.buildinfo")
            capture.unlink()
            results = validator.verify(output, None)
            self.assertTrue(all(ok for _, ok, _ in results), results)
            image.write_bytes(b"changed")
            self.assertFalse(all(ok for _, ok, _ in validator.verify(output, None)))

    def test_build_snapshot_records_profile_inputs_and_config(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-snapshot-") as scratch:
            root = Path(scratch)
            profile = root / "profile.conf"
            inputs = root / "overlay"
            output = root / "artifacts"
            capture = root / "capture.json"
            profile.write_text('PROFILE_NAME="demo"\n', encoding="utf-8")
            inputs.mkdir()
            (inputs / "probe.txt").write_text("fixture\n", encoding="utf-8")
            output.mkdir()
            (output / "config.buildinfo").write_text("CONFIG_CCACHE=y\n", encoding="utf-8")
            validator.capture(profile, "demo", [f"custom_files={inputs}"], capture)
            validator.finalize(capture, output, "sourcebuilder", output / "config.buildinfo")
            snapshot = json.loads((output / validator.SNAPSHOT).read_text(encoding="utf-8"))
            self.assertEqual(snapshot["profile_sha256"], hashlib.sha256(profile.read_bytes()).hexdigest())
            self.assertEqual(snapshot["inputs"]["custom_files"], validator.tree_hash(inputs))
            self.assertEqual(snapshot["config_sha256"], hashlib.sha256((output / "config.buildinfo").read_bytes()).hexdigest())
            self.assertIn("*routerfw-build-snapshot.json", (output / "sha256sums").read_text(encoding="utf-8"))

    def test_rejects_unrelated_profile_in_profiles_json(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-wrong-target-") as scratch:
            root = Path(scratch)
            (root / "profiles").mkdir()
            profile = root / "profiles" / "demo.conf"
            profile.write_text('TARGET_PROFILE="expected"\n', encoding="utf-8")
            output = root / "artifacts"
            output.mkdir()
            image = output / "image.bin"
            image.write_bytes(b"firmware")
            (output / "demo.manifest").write_text("base-files - 1\n", encoding="utf-8")
            (output / "profiles.json").write_text(json.dumps({"profiles": {
                "unrelated": {"images": [{"name": "image.bin", "size": 8,
                    "sha256": hashlib.sha256(image.read_bytes()).hexdigest()}]}
            }}), encoding="utf-8")
            capture = root / "capture.json"
            validator.capture(profile, "demo", [], capture)
            validator.finalize(capture, output, "sourcebuilder", None)
            with mock.patch.object(validator, "ROOT", root):
                checks = {name: (ok, detail) for name, ok, detail in validator.verify(output, "demo")}
            self.assertFalse(checks["profiles.json images"][0], checks)
            self.assertIn("expected", checks["profiles.json images"][1])

    def test_unlisted_nested_sha256sums_is_not_exempted(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-nested-sha-") as scratch:
            root = Path(scratch)
            profile = root / "profile.conf"
            profile.write_text('PROFILE_NAME="demo"\n', encoding="utf-8")
            output = root / "artifacts"
            output.mkdir()
            image = output / "image.bin"
            image.write_bytes(b"firmware")
            config = output / "config.buildinfo"
            config.write_text("CONFIG_CCACHE=y\n", encoding="utf-8")
            (output / "demo.manifest").write_text("base-files - 1\n", encoding="utf-8")
            (output / "profiles.json").write_text(json.dumps({"profiles": {
                "demo": {"images": [{"name": image.name, "size": image.stat().st_size,
                    "sha256": hashlib.sha256(image.read_bytes()).hexdigest()}]}
            }}), encoding="utf-8")
            capture = root / "capture.json"
            validator.capture(profile, "demo", [], capture)
            validator.finalize(capture, output, "sourcebuilder", config)
            before = {name: ok for name, ok, _ in validator.verify(output, None)}
            self.assertTrue(before["SHA256 manifest"])
            nested = output / "nested" / "sha256sums"
            nested.parent.mkdir()
            nested.write_text("untracked entry\n", encoding="utf-8")
            after = {name: (ok, detail) for name, ok, detail in validator.verify(output, None)}
            self.assertFalse(after["SHA256 manifest"][0], after)
            self.assertIn("nested/sha256sums", after["SHA256 manifest"][1])

    def test_rejects_malformed_profile_metadata_without_crashing(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-bad-metadata-") as scratch:
            root = Path(scratch)
            output = root / "artifacts"
            output.mkdir()
            (output / "profiles.json").write_text(json.dumps({
                "profiles": {"demo": {"images": ["invalid-image-entry"]}}
            }), encoding="utf-8")
            checks = {name: (ok, detail) for name, ok, detail in validator.verify(output, None)}
            self.assertFalse(checks["profiles.json images"][0], checks)
            self.assertIn("malformed", checks["profiles.json images"][1])

    def test_missing_config_hash_is_not_reported_as_verified(self):
        with tempfile.TemporaryDirectory(prefix="routerfw-no-config-") as scratch:
            root = Path(scratch)
            profile = root / "demo.conf"
            profile.write_text('PROFILE_NAME="demo"\n', encoding="utf-8")
            output = root / "artifacts"
            output.mkdir()
            image = output / "image.bin"
            image.write_bytes(b"firmware")
            (output / "demo.manifest").write_text("base-files - 1\n", encoding="utf-8")
            (output / "profiles.json").write_text(json.dumps({"profiles": {
                "demo": {"images": [{"name": image.name, "size": 8,
                    "sha256": hashlib.sha256(image.read_bytes()).hexdigest()}]}
            }}), encoding="utf-8")
            capture = root / "capture.json"
            validator.capture(profile, "demo", [], capture)
            validator.finalize(capture, output, "imagebuilder", output / "missing-config")
            checks = {name: (ok, detail) for name, ok, detail in validator.verify(output, None)}
            self.assertFalse(checks["build config snapshot"][0], checks)
            self.assertIn("hash missing", checks["build config snapshot"][1])


if __name__ == "__main__":
    unittest.main()
