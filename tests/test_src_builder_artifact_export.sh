#!/usr/bin/env bash
# file: tests/test_src_builder_artifact_export.sh
# Source Builder export contract: standalone/offline, no Docker or firmware builds.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tests/test_tmp.sh"
export TMPDIR="$(routerfw_test_tmp "$ROOT")"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
awk '/^# BEGIN SOURCE ARTIFACT EXPORT HELPERS/ {found=1; inside=1; next} /^# END SOURCE ARTIFACT EXPORT HELPERS/ {inside=0; exit} inside {print} END {if (!found) exit 1}' "$ROOT/system/src_builder.sh" > "$TMP/helpers.sh"
bash -n "$TMP/helpers.sh"
# shellcheck source=/dev/null
source "$TMP/helpers.sh"
# Keep this offline regression independent of the host's optional rsync binary.
# The exporter contract only uses archive copy plus exclusion of root packages/.
rsync() {
    [[ $# -eq 5 && "$1" == -a && "$2" == --exclude=/packages && "$3" == -- ]] || return 2
    local source=${4%/} entry
    for entry in "$source"/* "$source"/.[!.]* "$source"/..?*; do
        [[ -e "$entry" || -L "$entry" ]] || continue
        [[ "$entry" == "$source/packages" ]] && continue
        cp -a -- "$entry" "$5/" || return
    done
}
OK=0
pass() { printf '[OK] %s\n' "$1"; OK=$((OK+1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || fail "Missing $1"; }
assert_missing() { [[ ! -e "$1" && ! -L "$1" ]] || fail "Unexpected $1"; }
assert_same() { cmp -s -- "$1" "$2" || fail "Files differ: $1 and $2"; }
assert_fails() { if "$@" > "$TMP/last-error" 2>&1; then fail 'Unexpected success'; fi; }
verify() { (cd "$1" && sha256sum --check --status sha256sums) || fail "Bad checksum in $1"; }
assert_no_leaks() {
    if find "$TMP/outputs" -maxdepth 1 \( -name '.routerfw-export.*' -o -name '.routerfw-source-list.*' -o -name '.routerfw-checksum-list.*' \) | grep -q .; then
        fail 'Export staging/list files leaked'
    fi
}
mkdir -p "$TMP/work/bin/targets/mediatek/filogic/packages" "$TMP/work/bin/targets/mediatek/mt7622" "$TMP/outputs"
cd "$TMP/work"
SRC=bin/targets/mediatek/filogic
printf 'build config\n' > .config
printf 'firmware\n' > "$SRC/router-sysupgrade.itb"
printf 'bootloader\n' > "$SRC/router-bl31-uboot.fip"
printf 'bootloader binary\n' > "$SRC/router-bootloader.bin"
printf 'package\n' > "$SRC/packages/example.apk"
printf 'package index\n' > "$SRC/packages/Packages.gz"
printf 'upstream checksums\n' > "$SRC/sha256sums"
printf 'metadata\n' > "$SRC/profiles.json"
printf 'buildinfo\n' > "$SRC/version.buildinfo"
mkdir -p "$SRC/other/deeper" "$SRC/empty" "$SRC/other/packages"
printf 'nested\n' > "$SRC/other/deeper/firmware.img"
printf 'nested firmware binary\n' > "$SRC/other/packages/firmware.blob"
printf 'other subtarget\n' > bin/targets/mediatek/mt7622/router.img
source_export_artifacts "$SRC" "$TMP/outputs" first > "$TMP/log"
assert_file "$TMP/outputs/first/router-sysupgrade.itb"
assert_file "$TMP/outputs/first/router-bootloader.bin"
assert_missing "$TMP/outputs/first/packages"
assert_file "$TMP/outputs/first/other/deeper/firmware.img"
assert_file "$TMP/outputs/first/other/packages/firmware.blob"
[[ -d "$TMP/outputs/first/empty" ]] || fail 'Empty directory lost'
assert_same "$SRC/sha256sums" "$TMP/outputs/first/.routerfw-upstream.sha256sums"
assert_file "$SRC/packages/example.apk"
assert_missing "$TMP/outputs/first/router.img"
verify "$TMP/outputs/first"
[[ ! -e "$TMP/outputs/first/packages" ]] || fail 'Build packages unexpectedly copied'
grep -Fq 'build.config' "$TMP/outputs/first/sha256sums" || fail 'build.config not checksummed'
! grep -Fq 'packages/example.apk' "$TMP/outputs/first/sha256sums" || fail 'Excluded package unexpectedly checksummed'
assert_no_leaks
pass 'selected firmware tree copied without root packages, source checksum and empty dirs retained'
source_export_artifacts "$SRC" "$TMP/outputs" second > "$TMP/log"
assert_same "$SRC/router-sysupgrade.itb" "$TMP/outputs/second/router-sysupgrade.itb"
assert_file "$SRC/router-bootloader.bin"
verify "$TMP/outputs/second"
pass 'incremental export never moves/removes source artifacts'
printf 'same basename, distinct path\n' > "$SRC/other/router-sysupgrade.itb"
source_export_artifacts "$SRC" "$TMP/outputs" nested > "$TMP/log"
assert_file "$TMP/outputs/nested/router-sysupgrade.itb"
assert_file "$TMP/outputs/nested/other/router-sysupgrade.itb"
verify "$TMP/outputs/nested"
pass 'duplicate basenames in different relative paths preserve both artifacts'
# All filenames, not an extension allowlist. NUL traversal handles unusual names.
printf 'arbitrary extension\n' > "$SRC/custom-artifact.xyz"
printf 'spaced name\n' > "$SRC/a file with spaces.bin"
printf 'newline\n' > "$SRC/line"$'\n'"break.bin"
source_export_artifacts "$SRC" "$TMP/outputs" strange > "$TMP/log"
assert_file "$TMP/outputs/strange/custom-artifact.xyz"
assert_file "$TMP/outputs/strange/a file with spaces.bin"
assert_file "$TMP/outputs/strange/line"$'\n'"break.bin"
verify "$TMP/outputs/strange"
pass 'arbitrary extensions, spaces and newline filenames preserved and checksummed'
ln -s 'router-sysupgrade.itb' "$SRC/symlink-to-image"
source_export_artifacts "$SRC" "$TMP/outputs" symlink > "$TMP/log"
[[ -L "$TMP/outputs/symlink/symlink-to-image" ]] || fail 'Internal symlink not preserved'
[[ "$(readlink "$TMP/outputs/symlink/symlink-to-image")" == router-sysupgrade.itb ]] || fail 'Symlink target changed'
verify "$TMP/outputs/symlink"
pass 'internal relative symlinks are safely preserved'
ln -s '/etc/passwd' "$SRC/absolute-symlink"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" absolute_symlink
assert_missing "$TMP/outputs/absolute_symlink"; rm "$SRC/absolute-symlink"
ln -s '../../../../../../../etc/passwd' "$SRC/escaping-symlink"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" escaping_symlink
assert_missing "$TMP/outputs/escaping_symlink"; rm "$SRC/escaping-symlink"
ln -s 'nonexistent' "$SRC/dangling-symlink"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" dangling_symlink
assert_missing "$TMP/outputs/dangling_symlink"; rm "$SRC/dangling-symlink"
ln -s 'packages/example.apk' "$SRC/symlink-to-excluded-package"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" excluded_package_link
assert_missing "$TMP/outputs/excluded_package_link"; rm "$SRC/symlink-to-excluded-package"
pass 'external, absolute, dangling and excluded-package symlinks cannot publish broken tree'
mkfifo "$SRC/special.fifo"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" special_file
assert_missing "$TMP/outputs/special_file"; rm "$SRC/special.fifo"
pass 'unknown special file types fail closed instead of silent omission'
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" first
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" '../unsafe'
pass 'existing destination and unsafe timestamp rejected without overwrite'
printf 'collision\n' > "$SRC/build.config"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" collision
assert_missing "$TMP/outputs/collision"; rm "$SRC/build.config"
printf 'collision\n' > "$SRC/.routerfw-upstream.sha256sums"
assert_fails source_export_artifacts "$SRC" "$TMP/outputs" reserved
assert_missing "$TMP/outputs/reserved"; rm "$SRC/.routerfw-upstream.sha256sums"
pass 'reserved metadata names fail instead of overwriting upstream files'
(
    rsync() { return 3; }
    assert_fails source_export_artifacts "$SRC" "$TMP/outputs" copy_error
)
assert_missing "$TMP/outputs/copy_error"
(
    find() { return 3; }
    assert_fails source_export_artifacts "$SRC" "$TMP/outputs" find_error
)
assert_missing "$TMP/outputs/find_error"
(
    cmp() { return 1; }
    assert_fails source_export_artifacts "$SRC" "$TMP/outputs" verify_error
)
assert_missing "$TMP/outputs/verify_error"
assert_no_leaks
pass 'failed copy, enumeration and byte-compare cannot publish partial outputs'
# Target-independent payload; empty/metadata-only/package-only must fail.
mkdir -p "$TMP/x86" "$TMP/meta" "$TMP/packages-only/packages" "$TMP/nothing"
printf 'disk\n' > "$TMP/x86/router.img.gz"
source_export_artifacts "$TMP/x86" "$TMP/outputs" x86 > "$TMP/log"
assert_file "$TMP/outputs/x86/router.img.gz"; verify "$TMP/outputs/x86"
pass 'generic exporter accepts arbitrary firmware names and formats'
printf 'meta\n' > "$TMP/meta/profiles.json"
printf 'checksum\n' > "$TMP/meta/sha256sums"
printf 'package\n' > "$TMP/packages-only/packages/foo.apk"
assert_fails source_export_artifacts "$TMP/meta" "$TMP/outputs" metadata_only
assert_fails source_export_artifacts "$TMP/packages-only" "$TMP/outputs" package_only
assert_fails source_export_artifacts "$TMP/nothing" "$TMP/outputs" empty
pass 'metadata-only, packages-only and empty directories are not mistaken for firmware'
mkdir -p "$TMP/no-bl2/bin/targets/mediatek/filogic" "$TMP/no-bl2-outputs"
cd "$TMP/no-bl2"
SRC=bin/targets/mediatek/filogic
printf 'CONFIG_PACKAGE_trusted-firmware-a-mt7981-ram-ddr3=y\n' > .config
printf 'firmware without standalone BL2\n' > "$SRC/router-sysupgrade.itb"
source_export_artifacts "$SRC" "$TMP/no-bl2-outputs" no_bl2 > "$TMP/log"
assert_file "$TMP/no-bl2-outputs/no_bl2/router-sysupgrade.itb"
assert_missing "$TMP/no-bl2-outputs/no_bl2/mt7981-ram-ddr3-bl2.bin"
verify "$TMP/no-bl2-outputs/no_bl2"
pass 'exporter does not impose a MediaTek BL2 requirement from .config'
if grep -Fq 'source_export_ensure_current_ram_bl2' "$ROOT/system/src_builder.sh"; then fail 'MediaTek BL2 preflight remains in production'; fi
grep -Fq 'source_export_artifacts "bin/targets/$SRC_TARGET/$SRC_SUBTARGET" /output "$TIMESTAMP"' "$ROOT/system/src_builder.sh" || fail 'Exporter is not using exact subtarget'
pass 'production wires only the generic selected-BIN_DIR exporter'
assert_no_leaks
printf 'Source Builder artifact export: %s tests passed\n' "$OK"
