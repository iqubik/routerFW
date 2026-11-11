"""Dockerfile package-download resilience and unpacker synchronization checks."""
from __future__ import annotations

import base64
import hashlib
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
DOCKERFILES = (
    "system/dockerfile",
    "system/dockerfile.legacy",
    "system/src.dockerfile",
    "system/src.dockerfile.legacy",
)


class DockerfileAptRetryTests(unittest.TestCase):
    def test_all_builder_images_retry_apt_downloads(self):
        for relative in DOCKERFILES:
            text = (ROOT / relative).read_text(encoding="utf-8")
            with self.subTest(dockerfile=relative):
                self.assertIn("apt-get -o Acquire::Retries=5 update", text)
                self.assertIn("apt-get -o Acquire::Retries=5 install -y", text)

    def test_both_unpackers_embed_the_same_dockerfiles_and_digests(self):
        for bundle_name, marker_prefix, command_prefix in (
            ("_unpacker.sh", b"#", b"decode_file"),
            ("_unpacker.bat", b"::", b"call :DECODE_FILE"),
        ):
            bundle = (ROOT / bundle_name).read_bytes()
            eol = b"\r\n" if bundle_name.endswith(".bat") else b"\n"
            for relative in DOCKERFILES:
                path = relative.encode("ascii")
                with self.subTest(unpacker=bundle_name, dockerfile=relative):
                    begin = marker_prefix + b" BEGIN_B64_ " + path + eol
                    end = marker_prefix + b" END_B64_ " + path + eol
                    start = bundle.index(begin) + len(begin)
                    stop = bundle.index(end, start)
                    payload = base64.b64decode(b"".join(bundle[start:stop].split()))
                    source = (ROOT / relative).read_bytes()
                    self.assertEqual(payload, source)
                    manifest = re.search(
                        re.escape(command_prefix) + rb' "' + re.escape(path)
                        + rb'" "([0-9a-f]{32})"',
                        bundle,
                    )
                    self.assertIsNotNone(manifest)
                    self.assertEqual(manifest.group(1).decode("ascii"), hashlib.md5(source).hexdigest())


if __name__ == "__main__":
    unittest.main()
