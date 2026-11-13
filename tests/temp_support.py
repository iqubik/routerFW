"""Keep Python regression fixtures in the repository's ignored scratch area."""

from pathlib import Path
import os
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
REPO_TMP = REPO / "tmp"
REPO_TMP.mkdir(parents=True, exist_ok=True)
WSL = sys.platform.startswith("linux") and (
    "WSL_INTEROP" in os.environ or "microsoft" in Path("/proc/version").read_text().lower()
)
TEST_TMP = (Path("/tmp") if WSL and os.stat(REPO).st_dev != os.stat("/tmp").st_dev
            else REPO_TMP)
TEST_TMP.mkdir(parents=True, exist_ok=True)
tempfile.tempdir = str(TEST_TMP)
