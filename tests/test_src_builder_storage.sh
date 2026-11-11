#!/usr/bin/env bash
# file: tests/test_src_builder_storage.sh
# Source Builder storage/fallback regression tests. No Docker, profile or firmware build required.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE="$ROOT/system/src_builder.sh"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

awk '
    /^# BEGIN SOURCE STORAGE HEALTH HELPERS / { in_block=1; next }
    /^# END SOURCE STORAGE HEALTH HELPERS/ { in_block=0; done=1; exit }
    in_block { print }
    END { if (!done) exit 1 }
' "$SOURCE" > "$TMP/storage_helpers.sh"
bash -n "$TMP/storage_helpers.sh"
# shellcheck source=/dev/null
source "$TMP/storage_helpers.sh"
RED=''
NC=''
OK=0

pass() { printf '[OK] %s\n' "$1"; OK=$((OK+1)); }
assert_eq() {
    if [[ "$1" != "$2" ]]; then
        printf '[FAIL] %s: expected <%s>, got <%s>\n' "$3" "$2" "$1" >&2
        exit 1
    fi
}
assert_contains() {
    if ! grep -Fq -- "$2" "$1"; then
        printf '[FAIL] Missing text: %s\n' "$2" >&2
        exit 1
    fi
}
assert_calls() {
    local expected="$1" actual
    actual=$(cat "$TMP/calls" 2>/dev/null || true)
    assert_eq "$actual" "$expected" 'make arguments / call count'
}

mkdir -p "$TMP/volume with spaces"
if storage_check smoke "$TMP/volume with spaces" > "$TMP/health.log" 2>&1; then
    assert_eq "$(find "$TMP/volume with spaces" -maxdepth 1 -type f -name '.routerfw-health.*' | wc -l | tr -d ' ')" 0 'temporary probe removed'
else
    cat "$TMP/health.log"; exit 1
fi
pass 'writable volume including spaces; no probe artifacts'

if storage_check missing "$TMP/not-present" > "$TMP/health.log" 2>&1; then exit 1; fi
assert_eq "$storage_error_code" STORAGE_PATH_MISSING 'missing volume status'
assert_eq "$storage_error_path" "$TMP/not-present" 'missing volume path'
assert_contains "$TMP/health.log" STORAGE_PATH_MISSING
pass 'missing volume -> STORAGE_PATH_MISSING'

for scenario in 'Read-only file system:STORAGE_READONLY' 'No space left on device:STORAGE_NO_SPACE' 'Input/output error:STORAGE_IO_ERROR' 'Permission denied:PERMISSION_ERROR' 'Disk quota exceeded:STORAGE_NO_SPACE' 'Unexpected failure:STORAGE_WRITE_ERROR'; do
    message=${scenario%:*}
    expected=${scenario##*:}
    (
        # Mock the OS error in the exact call used by storage_check.
        mktemp() { printf 'mktemp: %s\n' "$message" >&2; return 1; }
        if storage_check simulation "$TMP/volume with spaces" > "$TMP/health.log" 2>&1; then exit 1; fi
        assert_eq "$storage_error_code" "$expected" "mktemp error $message"
        assert_contains "$TMP/health.log" "$expected"
    )
    pass "OS write error -> $expected"
done

(
    df() {
        if [[ "$1" == -Pk ]]; then
            printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\nfake 100 100 0 100%% /tmp\n'
        else
            command df "$@"
        fi
    }
    if storage_check disk-full "$TMP/volume with spaces" > "$TMP/health.log" 2>&1; then exit 1; fi
    assert_eq "$storage_error_code" STORAGE_NO_SPACE '0 blocks'
)
pass 'df zero blocks -> STORAGE_NO_SPACE'

(
    df() {
        if [[ "$1" == -Pi ]]; then
            printf 'Filesystem Inodes IUsed IFree IUse%% Mounted on\nfake 200 200 0 100%% /tmp\n'
        else
            command df "$@"
        fi
    }
    if storage_check inodes-full "$TMP/volume with spaces" > "$TMP/health.log" 2>&1; then exit 1; fi
    assert_eq "$storage_error_code" STORAGE_NO_SPACE '0 inodes'
)
pass 'df zero inodes -> STORAGE_NO_SPACE'

(
    df() {
        if [[ "$1" == -Pi ]]; then
            printf 'df: inode statistics not supported\n' >&2
            return 1
        fi
        command df "$@"
    }
    storage_check no-inode-support "$TMP/volume with spaces" > "$TMP/health.log" 2>&1
    assert_contains "$TMP/health.log" 'WARN: df -Pi'
)
pass 'unavailable inode statistics do not falsely block build'

(
    df() {
        if [[ "$1" == -Pk ]]; then
            printf 'df: Input/output error\n' >&2
            return 1
        fi
        command df "$@"
    }
    if storage_check df-io "$TMP/volume with spaces" > "$TMP/health.log" 2>&1; then exit 1; fi
    assert_eq "$storage_error_code" STORAGE_IO_ERROR 'df block statistic I/O error'
)
pass 'df blocks I/O error -> STORAGE_IO_ERROR'

(
    df() {
        if [[ "$1" == -Pi ]]; then
            printf 'df: Input/output error\n' >&2
            return 1
        fi
        command df "$@"
    }
    if storage_check df-io-inodes "$TMP/volume with spaces" > "$TMP/health.log" 2>&1; then exit 1; fi
    assert_eq "$storage_error_code" STORAGE_IO_ERROR 'df inode statistic I/O error'
)
pass 'df inode I/O error -> STORAGE_IO_ERROR'

# Test the real compile/download control flow with mocked make and probe outcomes.
# The full storage probes were tested above; here isolate the retry state machine.
storage_check() { return 0; }
make() {
    printf '%s\n' "$*" >> "$TMP/calls"
    case "${MAKE_SCENARIO:-success}" in
        success) return 0 ;;
        fail) return 1 ;;
        fail-first) [[ $(wc -l < "$TMP/calls") -gt 1 ]] ;;
        *) return 97 ;;
    esac
}

: > "$TMP/calls"
MAKE_SCENARIO=success SRC_CORES=4
run_source_compile -j4 > "$TMP/compile.log" 2>&1
assert_calls '-j4'
pass 'successful parallel compile -> one make'

: > "$TMP/calls"
MAKE_SCENARIO=fail-first SRC_CORES=4
run_source_compile -j4 > "$TMP/compile.log" 2>&1
assert_calls $'-j4\n-j1 V=s'
pass 'ordinary parallel failure -> successful debug retry'

: > "$TMP/calls"
MAKE_SCENARIO=fail SRC_CORES=4
if run_source_compile -j4 > "$TMP/compile.log" 2>&1; then exit 1; fi
assert_calls $'-j4\n-j1 V=s'
assert_contains "$TMP/compile.log" 'cause not classified'
pass 'double compile failure -> BUILD FAILED; no invented storage diagnosis'

: > "$TMP/calls"
MAKE_SCENARIO=fail SRC_CORES=debug
if run_source_compile -j1 V=s > "$TMP/compile.log" 2>&1; then exit 1; fi
assert_calls '-j1 V=s'
pass 'debug compile failure -> no redundant retry'

(
    : > "$TMP/calls"
    MAKE_SCENARIO=fail SRC_CORES=4
    storage_check() { storage_error_code=STORAGE_READONLY; printf '%s\n' '[BUILD INFRA] STORAGE_READONLY' >&2; return 1; }
    if run_source_compile -j4 > "$TMP/compile.log" 2>&1; then exit 1; fi
    assert_calls '-j4'
    assert_contains "$TMP/compile.log" STORAGE_READONLY
)
pass 'storage failure after compile -> skip fallback'

(
    : > "$TMP/calls"
    MAKE_SCENARIO=fail SRC_CORES=4
    local_count=0
    storage_check() {
        local_count=$((local_count + 1))
        if [[ "$local_count" -eq 2 ]]; then
            printf '%s\n' '[BUILD INFRA] STORAGE_IO_ERROR' >&2
            return 1
        fi
        return 0
    }
    if run_source_compile -j4 > "$TMP/compile.log" 2>&1; then exit 1; fi
    assert_calls $'-j4\n-j1 V=s'
    assert_contains "$TMP/compile.log" STORAGE_IO_ERROR
)
pass 'storage failure after debug retry -> proper final infrastructure cause'

: > "$TMP/calls"
MAKE_SCENARIO=success
run_source_download > "$TMP/download.log" 2>&1
assert_calls 'download'
pass 'successful download -> one make download'

: > "$TMP/calls"
MAKE_SCENARIO=fail-first
run_source_download > "$TMP/download.log" 2>&1
assert_calls $'download\ndownload V=s'
pass 'download error with writable storage -> verbose retry'

: > "$TMP/calls"
MAKE_SCENARIO=fail
if run_source_download > "$TMP/download.log" 2>&1; then exit 1; fi
assert_calls $'download\ndownload V=s'
assert_contains "$TMP/download.log" 'cause not classified'
pass 'double download failure -> no fake storage diagnosis'

(
    : > "$TMP/calls"
    MAKE_SCENARIO=fail
    storage_check() { storage_error_code=STORAGE_NO_SPACE; return 1; }
    if run_source_download > "$TMP/download.log" 2>&1; then exit 1; fi
    assert_calls 'download'
)
pass 'download storage failure -> skip verbose retry'

# Execute the actual top-level build orchestration (not just the helper functions)
# with mock make/df and without touching real OpenWrt volumes.
sed -n "/^storage_check 'before make download' || exit 1$/,/^# 6. СОХРАНЕНИЕ/p" "$SOURCE" | sed '$d' > "$TMP/compile_flow.sh"
bash -n "$TMP/compile_flow.sh"
if ! grep -Fq 'run_source_compile "${MAKE_ARGS[@]}" || exit 1' "$TMP/compile_flow.sh"; then
    printf '[FAIL] main compile call not found in extracted orchestration\n' >&2
    exit 1
fi

: > "$TMP/calls"
(
    MAKE_SCENARIO=success SRC_CORES=safe
    nproc() { echo 4; }
    source "$TMP/compile_flow.sh" > "$TMP/flow.log" 2>&1
)
assert_calls $'download\n-j3'
pass 'main orchestration safe cores -> -j3 when nproc=4'

: > "$TMP/calls"
(
    MAKE_SCENARIO=success SRC_CORES=debug
    nproc() { echo 4; }
    source "$TMP/compile_flow.sh" > "$TMP/flow.log" 2>&1
)
assert_calls $'download\n-j1 V=s'
pass 'main orchestration debug cores -> -j1 V=s'

: > "$TMP/calls"
(
    MAKE_SCENARIO=success SRC_CORES=5
    nproc() { echo 4; }
    source "$TMP/compile_flow.sh" > "$TMP/flow.log" 2>&1
)
assert_calls $'download\n-j5'
pass 'main orchestration numeric cores -> -j5'

: > "$TMP/calls"
(
    MAKE_SCENARIO=success SRC_CORES=''
    nproc() { echo 4; }
    source "$TMP/compile_flow.sh" > "$TMP/flow.log" 2>&1
)
assert_calls $'download\n-j4'
pass 'main orchestration auto cores -> -j4'

: > "$TMP/calls"
(
    SRC_CORES=4
    nproc() { echo 4; }
    make() {
        printf '%s\n' "$*" >> "$TMP/calls"
        case "$*" in download) return 0;; -j4) return 1;; '-j1 V=s') return 0;; esac
        return 1
    }
    source "$TMP/compile_flow.sh" > "$TMP/flow.log" 2>&1
)
assert_calls $'download\n-j4\n-j1 V=s'
pass 'main orchestration parallel compile failure -> single debug retry'

: > "$TMP/calls"
if (
    storage_check() { return 1; }
    MAKE_SCENARIO=success SRC_CORES=4
    source "$TMP/compile_flow.sh" > "$TMP/flow.log" 2>&1
); then
    printf '[FAIL] build continued despite failed initial storage probe\n' >&2
    exit 1
fi
assert_calls ''
pass 'main orchestration failed preflight -> no make calls'

: > "$TMP/calls"
if (
    MAKE_SCENARIO=success SRC_CORES=4
    check_count=0
    storage_check() {
        check_count=$((check_count+1))
        [[ "$check_count" -lt 2 ]]
    }
    nproc() { echo 4; }
    source "$TMP/compile_flow.sh" > "$TMP/flow.log" 2>&1
); then
    printf '[FAIL] build continued despite failed precompile storage probe\n' >&2
    exit 1
fi
assert_calls 'download'
pass 'main orchestration failed precompile probe -> no compile'

# Guard that production actually calls the health probe at both stages.
for hook in "storage_check 'before make download' || exit 1" "storage_check 'before compile' || exit 1" 'run_source_download || exit 1' 'run_source_compile "${MAKE_ARGS[@]}" || exit 1'; do
    assert_contains "$SOURCE" "$hook"
done
pass 'production call-site wiring present'

printf '\nSource Builder storage tests: %s PASS, 0 FAIL\n' "$OK"

# Shared SB exporter is used by both the BAT and SH container entrypoints.
bash "$ROOT/tests/test_src_builder_artifact_export.sh"
