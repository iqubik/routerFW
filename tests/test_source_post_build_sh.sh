#!/usr/bin/env bash
# file: tests/test_source_post_build_sh.sh
# Functional regression for the real _Builder.sh build_routine post-build path.
# All Compose/container operations are mocked; real profiles, Docker and volumes
# are never touched. Scenarios run in isolated temporary working directories.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/routerfw-sh-postbuild.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

# Extract production helpers and the *whole* build_routine. This deliberately
# exercises the actual integration path rather than a rewritten test-only copy
# of the post-build decision logic.
awk '
    /^# BEGIN SOURCE OUTPUT HELPERS$/ { inside=1; next }
    /^# END SOURCE OUTPUT HELPERS$/ { inside=0 }
    inside { print; count++ }
    END { if (!count) exit 1 }
' "$ROOT/_Builder.sh" > "$TMP/production.sh"
awk '
    /^build_routine\(\) \{$/ { inside=1 }
    /^is_safe_profile_token\(\) \{$/ { inside=0 }
    inside { print; count++ }
    END { if (!count) exit 1 }
' "$ROOT/_Builder.sh" >> "$TMP/production.sh"
bash -n "$TMP/production.sh"
# shellcheck source=/dev/null
source "$TMP/production.sh"
declare -F source_output_snapshot source_output_new_dir source_output_ib_archive build_routine >/dev/null

# Only the host execution boundary is replaced; the builder itself is unchanged.
check_dir() { [ -d "$1" ] || mkdir -p -- "$1"; }
run_container() { [ "$1" = rm ] && [ "$2" = -f ]; }
fix_output_ownership() { return 0; }
sleep() { :; }

make_result() {
    local name="$1" config="$2" archive="$3"
    local dest="$HOST_OUTPUT_DIR/$name"
    mkdir -p -- "$dest"
    if [ "$config" != none ]; then
        printf '%s\n' "$config" > "$dest/build.config"
    fi
    if [ "$archive" = yes ]; then
        mkdir -p -- "$dest/nested"
        printf 'fixture, not a real archive\n' > "$dest/nested/openwrt-imagebuilder-test.tar.zst"
    fi
}

run_compose() {
    local arg mode=""
    for arg in "$@"; do
        case "$arg" in down|up) mode="$arg" ;; esac
    done
    case "$mode" in
        down) return 0 ;;
        up)
            case "$CASE" in
                fresh_decline|fresh_accept|cli_no_prompt|missing_snapshot)
                    make_result new 'CONFIG_IB=y' yes ;;
                old_only) : ;;
                new_not_ib) make_result new '# CONFIG_IB is not set' yes ;;
                new_no_config) make_result new none yes ;;
                new_no_archive) make_result new 'CONFIG_IB=y' no ;;
                ambiguous_new_directories)
                    make_result new1 'CONFIG_IB=y' yes
                    make_result new2 'CONFIG_IB=y' yes ;;
                commented_only_accept) make_result new 'CONFIG_IB=y' yes ;;
                failed_build)
                    make_result new 'CONFIG_IB=y' yes
                    return 42 ;;
                *) printf 'Unknown scenario: %s\n' "$CASE" >&2; return 99 ;;
            esac
            # Simulate an unavailable/removed snapshot after a successful build.
            # Bash's dynamic local scope exposes the production variable here.
            if [ "$CASE" = missing_snapshot ]; then
                rm -f -- "$output_snapshot_file"
            fi
            return 0 ;;
        *) printf 'Unexpected Compose invocation: %s\n' "$*" >&2; return 99 ;;
    esac
}

# Neutral colors, fixed test markers. These are ordinary translations, not
# replacements for the production post-build implementation.
C_LBL='' C_VAL='' C_ERR='' C_RST='' C_KEY='' C_GRY='' C_YEL=''
L_BUILD_TARGET='fixture'
L_FINISHED='BUILD_FINISHED'
L_BUILD_FATAL='BUILD_FAILED'
L_IB_UPDATE_ASK='ROUTERFW_POSTBUILD_OFFER'
L_IB_UPDATE_PROMPT='Update ImageBuilder?'
L_IB_UPDATE_OK='ROUTERFW_POSTBUILD_UPDATED'
L_K_STAY='Stay in container?'
L_K_ENTER_SHELL='Shell'
L_K_SHELL_H3='Shell instructions'
BUILD_MODE=SOURCE

fail() { printf '[FAIL] %s: %s\n' "$CASE" "$*" >&2; return 1; }

run_case() (
    set -euo pipefail
    CASE="$1"
    local case_root="$TMP/fixture path 's/$CASE"
    mkdir -p -- "$case_root/profiles" "$case_root/tmp" "$case_root/firmware_output/sourcebuilder/fixture"
    cd -- "$case_root"
    export TMPDIR="$case_root/tmp"

    # The live URL is intentionally the last line: accepting an update must
    # comment it exactly once and insert exactly one new active URL.
    local original_profile
    if [ "$CASE" = commented_only_accept ]; then
        original_profile=$'SRC_BRANCH="v25.12.6"\n# profile marker\n#IMAGEBUILDER_URL="previous-url"\n'
    else
        original_profile=$'SRC_BRANCH="v25.12.6"\n# profile marker\nIMAGEBUILDER_URL="previous-url"\n'
    fi
    printf '%s' "$original_profile" > profiles/fixture.conf
    local before_sha after_sha expected_url expected_profile
    before_sha=$(sha256sum profiles/fixture.conf | awk '{print $1}')
    local out_root='firmware_output/sourcebuilder/fixture'
    case "$CASE" in
        fresh_decline|fresh_accept|old_only|new_not_ib|ambiguous_new_directories|cli_no_prompt|missing_snapshot)
            mkdir -p "$out_root/old/nested"
            printf 'CONFIG_IB=y\n' > "$out_root/old/build.config"
            printf 'historical\n' > "$out_root/old/nested/old-imagebuilder.tar.zst" ;;
    esac

    CLI_CMD=''
    [ "$CASE" = cli_no_prompt ] && CLI_CMD=BUILD
    case "$CASE" in
        fresh_accept|commented_only_accept) printf 'y\nn\n' > input.txt ;;
        *) printf 'n\nn\n' > input.txt ;;
    esac

    local rc=0
    build_routine fixture.conf < input.txt > result.txt 2>&1 || rc=$?
    local expect_rc=0
    [ "$CASE" = failed_build ] && expect_rc=42
    [ "$rc" -eq "$expect_rc" ] || fail "build exit $rc, expected $expect_rc; $(tail -10 result.txt)"

    local offer=0 updated=0 expect_offer=0 expect_updated=0
    grep -Fq ROUTERFW_POSTBUILD_OFFER result.txt && offer=1
    grep -Fq ROUTERFW_POSTBUILD_UPDATED result.txt && updated=1
    case "$CASE" in
        fresh_decline|fresh_accept|commented_only_accept|cli_no_prompt) expect_offer=1 ;;
    esac
    case "$CASE" in
        fresh_accept|commented_only_accept) expect_updated=1 ;;
    esac
    [ "$offer" -eq "$expect_offer" ] || fail "offer=$offer expected=$expect_offer; $(tail -12 result.txt)"
    [ "$updated" -eq "$expect_updated" ] || fail "updated=$updated expected=$expect_updated; $(tail -12 result.txt)"
    [ ! -e "$case_root/tmp"/tmp.* ] || fail 'snapshot temp file was not cleaned up'

    expected_url="$out_root/new/nested/openwrt-imagebuilder-test.tar.zst"
    if [ "$expect_offer" -eq 1 ]; then
        grep -Fq "$expected_url" result.txt || fail 'wrong ImageBuilder archive offered'
    fi
    if [ "$expect_updated" -eq 1 ]; then
        expected_profile=$(printf 'SRC_BRANCH="v25.12.6"\n# profile marker\n#IMAGEBUILDER_URL="previous-url"\nIMAGEBUILDER_URL="%s"\n' "$expected_url")
        # Compare files, not command-substitution values, to retain trailing EOL.
        printf '%s\n' "$expected_profile" > expected-profile.txt
        cmp -s profiles/fixture.conf expected-profile.txt || fail "incorrect profile rewrite: $(cat profiles/fixture.conf)"
    else
        after_sha=$(sha256sum profiles/fixture.conf | awk '{print $1}')
        [ "$after_sha" = "$before_sha" ] || fail 'profile changed despite decline/no offer'
    fi
    printf '[OK] %s\n' "$CASE"
)

for scenario in \
    fresh_decline old_only new_not_ib new_no_config new_no_archive \
    ambiguous_new_directories missing_snapshot fresh_accept \
    commented_only_accept cli_no_prompt failed_build; do
    run_case "$scenario"
done
printf '[OK] Source Builder post-build: 11 functional Bash integration scenarios passed\n'
