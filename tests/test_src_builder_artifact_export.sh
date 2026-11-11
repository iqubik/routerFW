#!/usr/bin/env bash
# file: tests/test_src_builder_artifact_export.sh
# Offline export fixture: no Docker, network, rsync or real firmware build.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
awk '/^# BEGIN SOURCE ARTIFACT EXPORT HELPERS/ {found=1; inside=1; next} /^# END SOURCE ARTIFACT EXPORT HELPERS/ {inside=0; exit} inside {print} END {if (!found) exit 1}' "$ROOT/system/src_builder.sh" > "$TMP/export.sh"
bash -n "$TMP/export.sh"
# shellcheck source=/dev/null
source "$TMP/export.sh"
OK=0
pass() { printf '[OK] %s\n' "$1"; OK=$((OK+1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || fail "Missing $1"; }
assert_missing() { [[ ! -e "$1" && ! -L "$1" ]] || fail "Unexpected $1"; }
assert_same() { cmp -s -- "$1" "$2" || fail "Files differ: $1 $2"; }
assert_fails() { if "$@" > "$TMP/err" 2>&1; then fail 'Unexpected export success'; fi; }
mkdir -p "$TMP/work/bin/targets/mediatek/filogic/packages" "$TMP/outputs"
cd "$TMP/work"
SRC=bin/targets/mediatek/filogic
printf 'same config\n' > .config
printf 'firmware\n' > "$SRC/router-sysupgrade.itb"
printf 'uboot\n' > "$SRC/router-bl31-uboot.fip"
printf 'ram preloader\n' > "$SRC/mt7981-ram-ddr3-bl2.bin"
printf 'package must not be exported\n' > "$SRC/packages/foo.apk"
printf 'config metadata\n' > "$SRC/config.buildinfo"
printf 'feed metadata\n' > "$SRC/feeds.buildinfo"
printf 'version metadata\n' > "$SRC/version.buildinfo"
printf 'old checksum\n' > "$SRC/sha256sums"
source_export_artifacts "$SRC" "$TMP/outputs" first > "$TMP/log"
assert_file "$TMP/outputs/first/mt7981-ram-ddr3-bl2.bin"
assert_file "$SRC/mt7981-ram-ddr3-bl2.bin"
assert_missing "$TMP/outputs/first/foo.apk"
(cd "$TMP/outputs/first" && sha256sum --check --status sha256sums) || fail 'First checksum invalid'
grep -q 'build.config' "$TMP/outputs/first/sha256sums" || fail 'build.config missing from checksums'
pass 'first export copies all artifacts; preserves source and checksums build.config'
source_export_artifacts "$SRC" "$TMP/outputs" second > "$TMP/log"
assert_same "$TMP/outputs/first/mt7981-ram-ddr3-bl2.bin" "$TMP/outputs/second/mt7981-ram-ddr3-bl2.bin"
assert_file "$SRC/mt7981-ram-ddr3-bl2.bin"
pass 'second incremental export remains complete with no regeneration'
# Emulate the legacy destructive move from an earlier version of routerFW.
rm "$SRC/mt7981-ram-ddr3-bl2.bin"
source_export_artifacts "$SRC" "$TMP/outputs" legacy_repair > "$TMP/log"
assert_file "$TMP/outputs/legacy_repair/mt7981-ram-ddr3-bl2.bin"
assert_same "$TMP/outputs/first/mt7981-ram-ddr3-bl2.bin" "$TMP/outputs/legacy_repair/mt7981-ram-ddr3-bl2.bin"
assert_missing "$SRC/mt7981-ram-ddr3-bl2.bin"
(cd "$TMP/outputs/legacy_repair" && sha256sum --check --status sha256sums) || fail 'Recovered checksums invalid'
pass 'legacy BL2 restored from verified prior profile output; bin directory untouched'
# A different config may change the bootloader; never inject stale bytes.
printf 'different config\n' > .config
source_export_artifacts "$SRC" "$TMP/outputs" new_config > "$TMP/log"
assert_missing "$TMP/outputs/new_config/mt7981-ram-ddr3-bl2.bin"
pass 'legacy recovery blocks mismatched .config'
printf 'same config\n' > .config
# A modified historical BL2 must fail its own previous SHA256 manifest.
mkdir -p "$TMP/outputs/old_corrupt"
cp "$TMP/outputs/first/"* "$TMP/outputs/old_corrupt/"
printf 'corrupt\n' > "$TMP/outputs/first/mt7981-ram-ddr3-bl2.bin"
rm -f "$TMP/outputs/second/mt7981-ram-ddr3-bl2.bin" "$TMP/outputs/legacy_repair/mt7981-ram-ddr3-bl2.bin"
# The earlier 'old_corrupt' directory still holds a valid candidate; remove it
# so this scenario has no trustworthy BL2 file.
rm -rf "$TMP/outputs/old_corrupt"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" corrupt_prior
assert_missing "$TMP/outputs/corrupt_prior/mt7981-ram-ddr3-bl2.bin"
pass 'tampered historical BL2 cannot be resurrected'
# Output collision is refused; no source file can be moved/deleted.
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" first
assert_file "$SRC/router-sysupgrade.itb"
pass 'existing result directory is not overwritten'
# Even when a nested target has a repeated basename, do not publish ambiguity.
mkdir -p "$SRC/deeper"; printf 'collision\n' > "$SRC/deeper/router-sysupgrade.itb"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" collide
assert_missing "$TMP/outputs/collide"
if compgen -G "$TMP/outputs/.routerfw-export.*" >/dev/null; then fail 'staging directory leaked'; fi
pass 'duplicate names abort transaction without partial output'
rm -rf "$SRC/deeper"
# Simulate I/O failure on source file: invalid path / missing directory.
assert_fails source_export_artifacts "$SRC/missing" "$TMP/outputs" missing
assert_missing "$TMP/outputs/missing"
pass 'missing target output never produces a false success'
# Regression: failed copy must abort instead of publishing an incomplete output.
(
    cp() { return 3; }
    assert_fails source_export_artifacts "$SRC" "$TMP/outputs" copy_failure
)
assert_missing "$TMP/outputs/copy_failure"
pass 'copy failure is fatal; no partial timestamp published'
# Regression: find error cannot be hidden by Bash process-substitution status.
(
    find() { return 3; }
    assert_fails source_export_artifacts "$SRC" "$TMP/outputs" find_failure
)
assert_missing "$TMP/outputs/find_failure"
pass 'enumeration failure is fatal; no partial timestamp published'
# Legacy recovery must not infer provenance when custom patches/hooks exist.
printf 'ram preloader\n' > "$TMP/outputs/first/mt7981-ram-ddr3-bl2.bin"
mkdir -p "$TMP/custom-patches" "$TMP/custom-files"
printf 'custom patch\n' > "$TMP/custom-patches/patch.txt"
ROUTERFW_PATCH_SOURCE="$TMP/custom-patches" ROUTERFW_FILES_SOURCE="$TMP/custom-files" \
    source_export_artifacts "$SRC" "$TMP/outputs" custom_patch > "$TMP/log"
assert_missing "$TMP/outputs/custom_patch/mt7981-ram-ddr3-bl2.bin"
rm "$TMP/custom-patches/patch.txt"
printf '#!/bin/sh\n' > "$TMP/custom-files/hooks.sh"
ROUTERFW_PATCH_SOURCE="$TMP/custom-patches" ROUTERFW_FILES_SOURCE="$TMP/custom-files" \
    source_export_artifacts "$SRC" "$TMP/outputs" custom_hook > "$TMP/log"
assert_missing "$TMP/outputs/custom_hook/mt7981-ram-ddr3-bl2.bin"
pass 'legacy BL2 recovery disabled for custom patches or hooks'
printf 'Source Builder artifact export: %d tests passed\n' "$OK"
