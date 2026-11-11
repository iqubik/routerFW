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
# Regression from real RAX3000M SB Hook v1/v2/OFF: both hook runs silently
# exported 18 files (zero RAM BL2) while Hook OFF recovered 7 legacy BL2.
# The source .config explicitly selects seven RAM-boot TFA packages.
mkdir -p "$TMP/ramwork/bin/targets/mediatek/filogic" "$TMP/ramout" "$TMP/hooks-dir"
cd "$TMP/ramwork"
SRC=bin/targets/mediatek/filogic
printf 'image\n' > "$SRC/router-sysupgrade.itb"
printf 'uboot\n' > "$SRC/router-bl31-uboot.fip"
cat > .config <<'EOF_RAM_CONFIG'
CONFIG_PACKAGE_trusted-firmware-a-mt7981-ram-ddr3=y
CONFIG_PACKAGE_trusted-firmware-a-mt7981-ram-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7986-ram-ddr3=y
CONFIG_PACKAGE_trusted-firmware-a-mt7986-ram-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7987-ram-comb=y
CONFIG_PACKAGE_trusted-firmware-a-mt7988-ram-comb=y
CONFIG_PACKAGE_trusted-firmware-a-mt7988-ram-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7981-emmc-ddr3-1866=y
EOF_RAM_CONFIG
printf '#!/bin/bash\n' > "$TMP/hooks-dir/hooks.sh"
ROUTERFW_FILES_SOURCE="$TMP/hooks-dir" assert_fails source_export_artifacts "$SRC" "$TMP/ramout" hook_incomplete
assert_missing "$TMP/ramout/hook_incomplete"
pass 'missing selected RAM BL2 refuses incomplete export even with custom hook'
# Model the upstream package-bin.mk install: it writes RAM BL2 directly
# to BIN_DIR only on the targeted compile/install, after the world build.
MAKE_ARGS=(-j2)
make() {
    printf '%s\n' "$*" >> "$TMP/make.calls"
    case "$*" in
        'package/boot/arm-trusted-firmware-mediatek/clean') return 0 ;;
        '-j2 package/boot/arm-trusted-firmware-mediatek/compile')
            local name
            for name in mt7981-ram-ddr3 mt7981-ram-ddr4 mt7986-ram-ddr3 mt7986-ram-ddr4 mt7987-ram-comb mt7988-ram-comb mt7988-ram-ddr4; do
                printf '%s fresh build\n' "$name" > "$SRC/$name-bl2.bin"
            done
            return 0 ;;
        *) return 99 ;;
    esac
}
run_source_compile() { fail 'Recovery must not run an additional make world'; }
source_export_ensure_current_ram_bl2 "$SRC" > "$TMP/ram-repair.log" 2>&1 || fail 'Targeted current-source TFA rebuild failed'
[[ $(wc -l < "$TMP/make.calls") -eq 2 ]] || fail 'Expected targeted clean plus targeted compile once'
ROUTERFW_FILES_SOURCE="$TMP/hooks-dir" source_export_artifacts "$SRC" "$TMP/ramout" hook_repaired > "$TMP/ram-repair.log" || fail 'Export of repaired selected BL2 failed'
[[ $(find "$TMP/ramout/hook_repaired" -maxdepth 1 -name 'mt*-bl2.bin' | wc -l) -eq 7 ]] || fail 'Expected exactly 7 BL2'
(cd "$TMP/ramout/hook_repaired" && sha256sum --check --status sha256sums) || fail 'Repaired build checksums invalid'
pass 'current-source rebuild restores exactly 7 selected RAM BL2 with valid hashes'
source_export_ensure_current_ram_bl2 "$SRC" >/dev/null || fail 'Complete selected RAM BL2 rejected'
[[ $(wc -l < "$TMP/make.calls") -eq 2 ]] || fail 'Unnecessary forced clean on repeat build'
pass 'second incremental build retains source BL2 without additional build'
printf '#!/bin/bash\n# hook v2\n' > "$TMP/hooks-dir/hooks.sh"
ROUTERFW_FILES_SOURCE="$TMP/hooks-dir" source_export_artifacts "$SRC" "$TMP/ramout" hook_v2 > "$TMP/ram-repair.log" || fail 'Hook v2 must retain complete RAM BL2 export'
[[ $(find "$TMP/ramout/hook_v2" -maxdepth 1 -name 'mt*-bl2.bin' | wc -l) -eq 7 ]] || fail 'Hook v2 missing BL2'
pass 'hook v1 to v2 retains all 7 current-source RAM BL2 artifacts'
rm -f -- "$SRC/mt7987-ram-comb-bl2.bin"
make() { [[ "$1" == package/boot/arm-trusted-firmware-mediatek/clean ]] && return 0; return 19; }
assert_fails source_export_ensure_current_ram_bl2 "$SRC"
assert_missing "$TMP/ramout/failed_rebuild"
pass 'failed targeted package compile aborts'
make() { return 20; }
assert_fails source_export_ensure_current_ram_bl2 "$SRC"
pass 'failed targeted clean aborts'
# Successful make that produced no BL2 must not yield false success.
make() { return 0; }
assert_fails source_export_ensure_current_ram_bl2 "$SRC"
pass 'no-op package compile cannot hide missing BL2'
# The configured debug arguments must pass through to targeted compile.
make() {
    printf '%s\n' "$*" >> "$TMP/debug.calls"
    case "$*" in
        'package/boot/arm-trusted-firmware-mediatek/clean') return 0 ;;
        '-j1 V=s package/boot/arm-trusted-firmware-mediatek/compile')
            printf 'rebuilt\n' > "$SRC/mt7987-ram-comb-bl2.bin" ;;
        *) return 22 ;;
    esac
}
MAKE_ARGS=(-j1 V=s)
source_export_ensure_current_ram_bl2 "$SRC" > "$TMP/debug-repair.log" 2>&1 || fail 'Debug-mode BL2 repair failed'
grep -Fxq -- '-j1 V=s package/boot/arm-trusted-firmware-mediatek/compile' "$TMP/debug.calls" || fail 'Debug make args not forwarded'
pass 'targeted compile uses selected debug arguments'
# Test non-TFA profiles: do not invent a global 7-BL2 invariant.
printf 'CONFIG_PACKAGE_other_package=y\n' > .config
source_export_ensure_current_ram_bl2 "$SRC" >/dev/null || fail 'Non-TFA profile should not require BL2'
pass 'profiles without selected RAM bootloaders are unaffected'
# The BL2 fix must not remove the new shared permissions policy wiring.
[[ -f "$ROOT/system/overlay_permissions.sh" ]] || fail 'New permissions module missing'
grep -Fq 'source /overlay_permissions.sh' "$ROOT/system/src_builder.sh" || fail 'SB permissions module disconnected'
grep -Fq 'routerfw_normalize_overlay_permissions "$stage"' "$ROOT/system/src_builder.sh" || fail 'SB staged permissions normalization removed'
pass 'BL2 patch preserves the new overlay permissions module integration'
# Production-wiring regression (caught by real SB/SH failure):
# exporter recursively scans bin/targets/<target>, while direct BL2 validation
# MUST use bin/targets/<target>/<subtarget>, where OpenWrt's BIN_DIR lives.
production_call=$(grep -F 'source_export_ensure_current_ram_bl2 "bin/targets/$SRC_TARGET' "$ROOT/system/src_builder.sh")
[[ $(printf '%s\n' "$production_call" | grep -c '^source_export_ensure_current_ram_bl2 ') -eq 1 ]] || fail 'Expected exactly one production BL2 check call'
grep -Fq 'bin/targets/$SRC_TARGET/$SRC_SUBTARGET' <<< "$production_call" || fail 'Production BL2 check missing subtarget component'
mkdir -p "$TMP/production/bin/targets/mediatek/filogic"
cat > "$TMP/production/.config" <<'EOF_PRODUCTION'
CONFIG_PACKAGE_trusted-firmware-a-mt7981-ram-ddr3=y
CONFIG_PACKAGE_trusted-firmware-a-mt7981-ram-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7986-ram-ddr3=y
CONFIG_PACKAGE_trusted-firmware-a-mt7986-ram-ddr4=y
CONFIG_PACKAGE_trusted-firmware-a-mt7987-ram-comb=y
CONFIG_PACKAGE_trusted-firmware-a-mt7988-ram-comb=y
CONFIG_PACKAGE_trusted-firmware-a-mt7988-ram-ddr4=y
EOF_PRODUCTION
for variant in mt7981-ram-ddr3 mt7981-ram-ddr4 mt7986-ram-ddr3 mt7986-ram-ddr4 mt7987-ram-comb mt7988-ram-comb mt7988-ram-ddr4; do
    printf 'fresh %s\n' "$variant" > "$TMP/production/bin/targets/mediatek/filogic/$variant-bl2.bin"
done
(
    cd "$TMP/production"
    SRC_TARGET=mediatek
    SRC_SUBTARGET=filogic
    make() { echo '[FAIL] False-negative BL2 check unexpectedly triggered make' >&2; return 91; }
    eval "$production_call"
) || fail 'Production BL2 check falsely rejects complete leaf BIN_DIR'
pass 'production SB invocation checks selected RAM BL2 in real <target>/<subtarget> layout'
# Extra defense: a BL2 in the parent is NOT an acceptable substitute.
rm -f -- "$TMP/production/bin/targets/mediatek/filogic/mt7981-ram-ddr3-bl2.bin"
printf 'bad parent file\n' > "$TMP/production/bin/targets/mediatek/mt7981-ram-ddr3-bl2.bin"
if (
    cd "$TMP/production"
    SRC_TARGET=mediatek
    SRC_SUBTARGET=filogic
    make() { return 91; }
    eval "$production_call"
) >/dev/null 2>&1; then
    fail 'Parent-directory BL2 incorrectly accepted in place of leaf BIN_DIR file'
fi
pass 'parent target directory cannot mask a missing selected BL2 in subtarget'
printf 'Source Builder artifact export: %d tests passed\n' "$OK"
