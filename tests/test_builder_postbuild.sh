#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/test_tmp.sh"
export TMPDIR="$(routerfw_test_tmp "$ROOT")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

awk '
    /# BEGIN SOURCE OUTPUT HELPERS/ { copy = 1; next }
    /# END SOURCE OUTPUT HELPERS/ { copy = 0 }
    copy
' "$ROOT/_Builder.sh" > "$TMP/helpers.sh"
# shellcheck disable=SC1091
source "$TMP/helpers.sh"

cat > "$TMP/profile.conf" <<'EOF'
#IMAGEBUILDER_URL="https://downloads.example/19.07/old.tar.zst"
IMAGEBUILDER_URL="https://downloads.example/targets/current/path.tar.zst"
EOF
value=$(source_profile_value IMAGEBUILDER_URL "$TMP/profile.conf")
[[ "$value" == 'https://downloads.example/targets/current/path.tar.zst' ]] || {
    echo "[FAIL] active profile value selected incorrectly: $value" >&2
    exit 1
}

OUT="$TMP/output"
mkdir -p "$OUT/older"
printf 'CONFIG_IB=y\n' > "$OUT/older/build.config"
printf 'old archive\n' > "$OUT/older/old-imagebuilder.tar.zst"
touch -t 203801010000 "$OUT/older"
source_output_snapshot "$OUT" "$TMP/before.txt"
mkdir -p "$OUT/current-disabled"
printf '# CONFIG_IB is not set\n' > "$OUT/current-disabled/build.config"
cp "$OUT/older/old-imagebuilder.tar.zst" "$OUT/current-disabled/old-imagebuilder.tar.zst"
current=$(source_output_new_dir "$OUT" "$TMP/before.txt")
[[ "$current" == "$OUT/current-disabled" ]] || { echo '[FAIL] selected output was not created by this run' >&2; exit 1; }
if source_output_ib_enabled "$current/build.config"; then
    echo '[FAIL] disabled ImageBuilder accepted a stale exported archive' >&2
    exit 1
fi

source_output_snapshot "$OUT" "$TMP/before-empty.txt"
mkdir -p "$OUT/current-no-archive"
printf 'CONFIG_IB=y\n' > "$OUT/current-no-archive/build.config"
current=$(source_output_new_dir "$OUT" "$TMP/before-empty.txt")
[[ "$current" == "$OUT/current-no-archive" ]] || { echo '[FAIL] output without an archive was not tied to this run' >&2; exit 1; }
if source_output_ib_archive "$current" >/dev/null; then
    echo '[FAIL] an archive from an older output was selected' >&2
    exit 1
fi

source_output_snapshot "$OUT" "$TMP/before-enabled.txt"
mkdir -p "$OUT/current-enabled"
printf 'CONFIG_IB=y\n' > "$OUT/current-enabled/build.config"
printf 'current archive\n' > "$OUT/current-enabled/current-imagebuilder.tar.zst"
current=$(source_output_new_dir "$OUT" "$TMP/before-enabled.txt")
[[ "$current" == "$OUT/current-enabled" ]] || { echo '[FAIL] current run output was not selected' >&2; exit 1; }
archive=$(source_output_ib_archive "$current") || { echo '[FAIL] enabled ImageBuilder archive was not found' >&2; exit 1; }
[[ "$archive" == "$current/current-imagebuilder.tar.zst" ]] || { echo "[FAIL] wrong archive selected: $archive" >&2; exit 1; }

# A missing snapshot must never make historical output appear current.
if source_output_new_dir "$OUT" "$TMP/missing-snapshot" >/dev/null 2>&1; then
    echo '[FAIL] missing snapshot accepted' >&2
    exit 1
fi
# A failing snapshot write must not be silently converted into success.
if [ -e /dev/full ] && source_output_snapshot "$OUT" /dev/full 2>/dev/null; then
    echo '[FAIL] write failure was hidden by snapshot helper' >&2
    exit 1
fi

source_output_snapshot "$OUT" "$TMP/before-ambiguous.txt"
mkdir -p "$OUT/parallel-a" "$OUT/parallel-b"
if source_output_new_dir "$OUT" "$TMP/before-ambiguous.txt" >/dev/null; then
    echo '[FAIL] ambiguous concurrent outputs were accepted' >&2
    exit 1
fi

echo '[OK] Source Builder post-build discovery: current output, CONFIG_IB, and active profile value'
