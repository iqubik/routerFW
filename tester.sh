#!/bin/bash
# file: tester.sh v1.2
#
# Автопроверка CLI _Builder.sh.
# Запуск без аргументов = все тесты.
# Запуск с аргументами = только тесты с указанными метками.
# Пример: ./tester.sh help "Localization Keys"
# Full CI checks (requires Docker, Podman, Compose, Python 3 and ShellCheck): ./tester.sh --ci
# Individual container checks: ./tester.sh "Docker Smoke" / ./tester.sh "Podman Smoke"
#
# Запуск без аргументов = все тесты.
# Запуск с аргументами = только тесты с указанными метками.
# Метки, содержащие пробелы, необходимо заключать в кавычки.
# Пример: ./tester.sh "Localization Keys" help
#
# Доступные метки:
# --- CLI (Коды выхода 0) ---
# help, -h, --help, state, s, ib help, src help, image help, source help,
# --lang=EN help, --lang=RU help, -l EN help, -l RU help, HELP
#
# --- CLI (Коды выхода 1) ---
# build (no id), build spaces, build 999999, build no_such,
# edit 999999, edit spaces, unknown -> profile not found,
# --state -> profile not found, --lang=XX help, --lang help, -l help,
# positional 999999, BUILD no id
#
# --- Health Checks (Проверки здоровья) ---
# Localization Keys
# BOM Signature
#

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SH="_Builder.sh"
PASS=0
FAIL=0
export ROUTERFW_NO_CLS=1
export ROUTERFW_TEST_MODE=1

LOG="$SCRIPT_DIR/tester_log_lin.md"
TASK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/routerfw-tester-sh.XXXXXX")"
TESTER_JOBS="${ROUTERFW_TEST_JOBS:-}"
if [ -z "$TESTER_JOBS" ]; then
  TESTER_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
fi
case "$TESTER_JOBS" in
  ''|*[!0-9]*) TESTER_JOBS=4 ;;
esac
[ "$TESTER_JOBS" -lt 1 ] && TESTER_JOBS=1
[ "$TESTER_JOBS" -gt 8 ] && TESTER_JOBS=8
echo "# tester.sh run $(date '+%Y-%m-%d %H:%M:%S')" > "$LOG"
echo "" >> "$LOG"
echo "Parallel jobs: $TESTER_JOBS" >> "$LOG"

TASK_PIDS=()
TASK_LABELS=()
TASK_KINDS=()
TASK_EXPECTS=()
TASK_OUTS=()
TASK_RCS=()
TASK_SEQ=0

cleanup_tester() {
  rm -rf "$TASK_DIR"
}
trap cleanup_tester EXIT

# 1. Сохраняем аргументы скрипта в глобальный массив, сохраняя пробелы
FULL_CI=0
if [ "${1:-}" = "--ci" ]; then
  FULL_CI=1
  shift
fi
FILTERS=("$@")

if [ ${#FILTERS[@]} -gt 0 ]; then
  echo "Running filtered tests: ${FILTERS[*]}"
  echo ""
fi

tee_line() {
  if [ -z "${TEE_LINE:-}" ]; then
    echo ""
    echo "" >> "$LOG"
  else
    echo "$TEE_LINE"
    echo "$TEE_LINE" >> "$LOG"
  fi
}

# Функция проверки фильтра (общая логика)
should_run() {
  local label="$1"
  # Если фильтров нет — запускаем всё
  if [ ${#FILTERS[@]} -eq 0 ]; then
    return 0 # true (bash shell exit code 0 means success/true)
  fi
  
  # Проверяем совпадение метки с одним из фильтров
  for filter in "${FILTERS[@]}"; do
    if [ "$filter" = "$label" ]; then
      return 0 # found match
    fi
  done
  
  return 1 # false (skip)
}

container_smoke() (
    set -e -o pipefail
    local runtime="$1" project="routerfw-smoke-$1-$$"
    unset ROUTERFW_TEST_MODE ROUTERFW_TEST_COMPOSE_LOG ROUTERFW_TEST_COMPOSE_PROVIDER
    unset ROUTERFW_TEST_BUILD_STATUS ROUTERFW_TEST_COMPOSE_ARGS ROUTERFW_TEST_COMPOSE_BASE
    export ROUTERFW_RUNTIME="$runtime"
    export SELECTED_CONF=tplink_tl_wr1043nd_v2_24105_ow_full.conf
    export HOST_PKGS_DIR="./custom_packages/${SELECTED_CONF%.conf}"
    export HOST_FILES_DIR="./custom_files/${SELECTED_CONF%.conf}"
    export HOST_PATCHES_DIR="./custom_patches/${SELECTED_CONF%.conf}"
    export HOST_OUTPUT_DIR="./firmware_output/sourcebuilder/$project"
    mkdir -p "$HOST_PKGS_DIR" "$HOST_FILES_DIR" "$HOST_PATCHES_DIR" \
        "firmware_output/imagebuilder/$project" "$HOST_OUTPUT_DIR"
    smoke_cleanup() {
        local base
        for base in system/docker-compose.yaml system/docker-compose-src.yaml; do
            ROUTERFW_TEST_COMPOSE_BASE="$base" ROUTERFW_TEST_COMPOSE_ARGS="-p $project down --volumes" \
                bash ./_Builder.sh help || return
        done
        rm -rf -- "firmware_output/imagebuilder/$project" "$HOST_OUTPUT_DIR"
    }
    trap smoke_cleanup EXIT

    local ib_output="/output/imagebuilder/$project"
    local ib_restore='' src_restore=''
    if [ "$runtime" = docker ]; then
        # Docker writes as root/build. Restore the bind directory's owner even on failure.
        ib_restore="trap \"chown -R \$(stat -c %u:%g $ib_output) $ib_output\" EXIT; "
        src_restore='trap "chown -R $(stat -c %u:%g /output) /output" EXIT; '
    fi

    check_smoke_output() {
        local file="$1"
        if [ ! -f "$file" ] || [ ! -w "$file" ]; then
            echo "[ERROR] Smoke output missing or not writable by UID $(id -u): $file" >&2
            return 1
        fi
        if [ "$runtime" = podman ] && [ "$(stat -c '%u' "$file")" != "$(id -u)" ]; then
            echo "[ERROR] Podman smoke output has an unexpected owner: $file" >&2
            return 1
        fi
    }

    export ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml
    ROUTERFW_TEST_COMPOSE_ARGS=config bash ./_Builder.sh help
    ROUTERFW_TEST_COMPOSE_ARGS="-p $project build builder-openwrt" bash ./_Builder.sh help
    local command="-p $project run --rm -T builder-openwrt sh -ec '${ib_restore}id; touch /builder_workspace/.routerfw-write-test; touch $ib_output/.routerfw-output-test; getconf GNU_LIBC_VERSION > $ib_output/glibc.txt'"
    ROUTERFW_TEST_COMPOSE_ARGS="$command" bash ./_Builder.sh help
    check_smoke_output "firmware_output/imagebuilder/$project/.routerfw-output-test"

    export HOST_PKGS_DIR="./src_packages/${SELECTED_CONF%.conf}"
    mkdir -p "$HOST_PKGS_DIR"
    export ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose-src.yaml
    ROUTERFW_TEST_COMPOSE_ARGS=config bash ./_Builder.sh help
    ROUTERFW_TEST_COMPOSE_ARGS="-p $project build builder-src-openwrt" bash ./_Builder.sh help
    command="-p $project run --rm -T builder-src-openwrt sh -ec '${src_restore}id; chown build:build /output; sudo -u build sh -ec \"id; echo ok > /output/result.txt; getconf GNU_LIBC_VERSION > /output/glibc.txt\"'"
    ROUTERFW_TEST_COMPOSE_ARGS="$command" bash ./_Builder.sh help
    check_smoke_output "$HOST_OUTPUT_DIR/result.txt"
    test "$(cat "$HOST_OUTPUT_DIR/result.txt")" = ok
    local ib_glibc src_glibc
    ib_glibc=$(awk '/^glibc /{print $2; exit}' "firmware_output/imagebuilder/$project/glibc.txt")
    src_glibc=$(awk '/^glibc /{print $2; exit}' "$HOST_OUTPUT_DIR/glibc.txt")
    test -n "$ib_glibc" && test -n "$src_glibc"
    test "$(printf '%s\n%s\n' "$ib_glibc" "$src_glibc" | sort -V | tail -1)" = "$ib_glibc"
    echo "Modern builder glibc invariant OK: image=$ib_glibc source=$src_glibc"
)
export -f container_smoke

run() {
  local expect="$1"
  local label="$2"
  shift 2
  enqueue_task "$expect" "$label" "Test" bash "$SCRIPT_DIR/$SH" "$@"
}

run_check() {
  local expect="$1"
  local label="$2"
  local cmd="$3"
  enqueue_task "$expect" "$label" "Check" bash -c "$cmd"
}

run_env() {
  local expect="$1"
  local label="$2"
  shift 2
  enqueue_task "$expect" "$label" "Test" env "$@"
}

enqueue_task() {
  local expect="$1"
  local label="$2"
  local kind="$3"
  shift 3

  if ! should_run "$label"; then
    return 0
  fi

  if [ "${#TASK_PIDS[@]}" -ge "$TESTER_JOBS" ]; then
    wait_all
  fi

  local out="$TASK_DIR/$TASK_SEQ.out"
  local rc_file="$TASK_DIR/$TASK_SEQ.rc"
  (
    set +e
    TIMEFORMAT='%3R'
    { time "$@" > "$out" 2>&1; got=$?; } 2> "$rc_file.time"
    printf '%s\n' "$got" > "$rc_file"
  ) &

  TASK_PIDS+=("$!")
  TASK_LABELS+=("$label")
  TASK_KINDS+=("$kind")
  TASK_EXPECTS+=("$expect")
  TASK_OUTS+=("$out")
  TASK_RCS+=("$rc_file")
  ((TASK_SEQ++)) || true
}

wait_all() {
  local i pid label kind expect out rc_file got duration milliseconds
  [ "${#TASK_PIDS[@]}" -eq 0 ] && return 0

  for pid in "${TASK_PIDS[@]}"; do
    wait "$pid" || true
  done

  for i in "${!TASK_PIDS[@]}"; do
    label="${TASK_LABELS[$i]}"
    kind="${TASK_KINDS[$i]}"
    expect="${TASK_EXPECTS[$i]}"
    out="${TASK_OUTS[$i]}"
    rc_file="${TASK_RCS[$i]}"
    got=255
    [ -f "$rc_file" ] && got="$(cat "$rc_file")"

    TEE_LINE="" tee_line
    TEE_LINE="--- $kind: $label ---" tee_line
    [ -f "$out" ] && cat "$out"
    [ -f "$out" ] && cat "$out" >> "$LOG"

    TEE_LINE="" tee_line
    if [ "$expect" = "$got" ]; then
      TEE_LINE="[OK] $label" tee_line
      ((PASS++)) || true
    else
      TEE_LINE="[FAIL] $label (expected exit $expect, got $got)" tee_line
      ((FAIL++)) || true
    fi
    if IFS= read -r duration < "$rc_file.time" &&
       [[ "$duration" =~ ^([0-9]+)[.,]([0-9]{3})$ ]]; then
      milliseconds=$((10#${BASH_REMATCH[1]} * 1000 + 10#${BASH_REMATCH[2]}))
      TEE_LINE="[TIME] $milliseconds ms | $label" tee_line
      printf '%s\n' "$milliseconds ms | $label" >> "$TASK_DIR/timings"
    fi
  done

  TASK_PIDS=()
  TASK_LABELS=()
  TASK_KINDS=()
  TASK_EXPECTS=()
  TASK_OUTS=()
  TASK_RCS=()
}

TEE_LINE="" tee_line
TEE_LINE="=== routerFW Bash test suite ===" tee_line
TEE_LINE="" tee_line

# --- Ожидание: exit 0 ---
run 0 "help" help
run 0 "-h" -h
run 0 "--help" --help
run 0 "state" state
run 0 "s" s
run 0 "ib help" ib help
run 0 "src help" src help
run 0 "image help" image help
run 0 "source help" source help
run 0 "--lang=EN help" --lang=EN help
run 0 "--lang=RU help" --lang=RU help
run 0 "-l EN help" -l EN help
run 0 "-l RU help" -l RU help
run 0 "--runtime=auto help" --runtime=auto help
run 0 "--runtime=docker help" --runtime=docker help
run 0 "--runtime=podman help" --runtime=podman help

# --- Ожидание: exit 1 (ошибки) ---
run 1 "build (no id)" build
run 1 "build spaces" build "   "
run 1 "build 999999" build 999999
run 1 "build no_such" build no_such_profile_xyz
run 1 "edit 999999" edit 999999
run 1 "edit spaces" edit "   "
run 1 "unknown -> profile not found" unknown_cmd_xyz
run 1 "--state -> profile not found" --state
run 1 "--lang=XX help" --lang=XX help
run 1 "--lang help" --lang help
run 1 "-l help" -l help
run 1 "--runtime=bad help" --runtime=bad help
run 1 "--runtime help" --runtime help
run 1 "-r help" -r help
run 1 "positional 999999" 999999
run 1 "build path traversal" build ../evil
run 1 "src menuconfig no id" src menuconfig
run 1 "ib menuconfig 1" ib menuconfig 1

# --- Регистр ---
run 0 "HELP" HELP
run 1 "BUILD no id" BUILD
run_env 0 "build forced 0" ROUTERFW_TEST_BUILD_STATUS=0 bash "$SCRIPT_DIR/$SH" build 1
run_env 1 "build forced 1" ROUTERFW_TEST_BUILD_STATUS=1 bash "$SCRIPT_DIR/$SH" build 1
run_env 42 "build forced 42" ROUTERFW_TEST_BUILD_STATUS=42 bash "$SCRIPT_DIR/$SH" build 1
run_env 0 "build-all forced 0" ROUTERFW_TEST_BUILD_STATUS=0 bash "$SCRIPT_DIR/$SH" build-all
run_env 1 "build-all forced 1" ROUTERFW_TEST_BUILD_STATUS=1 bash "$SCRIPT_DIR/$SH" build-all

# ========== НЕ ТЕСТИРУЕМ (раскомментировать для полного прогона) ==========
# --- реальные сборки: долгие процессы, проверять вручную; N = существующий профиль ---
# run 0 "build N" build 1
# run 0 "b N" b 1
# run 0 "build name" build myprofile
# run 0 "build-all" build-all
# run 0 "all" all
# run 0 "a" a
# run 0 "ib build N" ib build 1
# run 0 "src build N" src build 1
# run 0 "positional N" 1
# --- menuconfig: требует id, в SOURCE открывает mc; в IB даёт SOURCE only ---
# run 1 "menuconfig (no id)" menuconfig
# run 1 "menuconfig 999999" menuconfig 999999
# run 1 "ib menuconfig 1 (SOURCE only)" ib menuconfig 1
# --- import: то же; wizard и clean — интерактивны или меняют систему ---
# run 1 "import (no id)" import
# run 1 "ib import 1 (SOURCE only)" ib import 1
# --- wizard / profile wizard (запуск create_profile) ---
# run 0 "wizard" wizard
# run 0 "w" w
# --- clean: сценарии очистки меняют кэши/контейнеры; global prune отключён ---
# run 1 "clean 0 1" clean 0 1
# run 1 "clean 7 1 (IMAGE)" clean 7 1
# run 1 "clean 09 1" clean 09 1
# run 1 "clean 4 1 (IMAGE, 4 only SOURCE)" clean 4 1
# clean без аргументов → интерактивное меню (не проверяем автоматически)
# clean 9 → global prune disabled (не выполняется)
# clean 1 N, clean 2 N ... → реальная очистка (не проверяем)

# --- Project Health Checks ---
wait_all
TEE_LINE="" tee_line
TEE_LINE="=== Project Health Checks ===" tee_line
TEE_LINE="" tee_line

# Сравнение ключей
run_check 0 "Source Builder Storage Recovery" "bash tests/test_src_builder_storage.sh && bash tests/test_src_builder_git_feeds.sh && bash tests/test_src_builder_lifecycle.sh"
run_check 0 "Source Builder Post-Build Discovery" "bash tests/test_builder_postbuild.sh && bash tests/test_source_post_build_sh.sh"
run_check 0 "Source Tree Packager" 'if command -v python3 >/dev/null 2>&1 && python3 -c "import sys; assert sys.version_info >= (3, 10)"; then python3 tests/run_unittest.py; elif [ -n "${CI:-}" ]; then echo "[FAIL] CI requires Python 3.10+ for source exporter regressions"; exit 1; else echo "[SKIP] Optional Python 3.10+ unavailable; source packaging tests not run"; fi'
run_check 0 "Bash Syntax" 'set -e -o pipefail; for f in _Builder.sh _unpacker.sh tester.sh system/*.sh tests/*.sh; do bash -n "$f"; done; git ls-files -z -- "custom_files/**/*.sh" "scripts/**/*.sh" "scripts/*.sh" | xargs -0 -r -n1 bash -n'
run_check 0 "ShellCheck" 'command -v shellcheck >/dev/null || { echo "Install shellcheck to run the same checks as CI"; exit 1; }; shellcheck --severity=error _Builder.sh tester.sh system/*.sh'
run_check 0 "Localization Keys" "diff <(grep -E '^(L_|H_)' system/lang/ru.env | sed 's/=.*//' | sort) <(grep -E '^(L_|H_)' system/lang/en.env | sed 's/=.*//' | sort)"
run_check 0 "Version Sync" "ver=\$(grep -E '^ROUTERFW_VERSION=' system/version.env | cut -d= -f2 | tr -d '\r'); grep -Fq \"VER_NUM=\\\"\$ver\\\"\" _Builder.sh && grep -Fq \"set \\\"VER_NUM=\$ver\\\"\" _Builder.bat && grep -Fq \"v\$ver+\" README.md && grep -Fq \"v\$ver+\" README.en.md && grep -Fq \"Version: \$ver.\" docs/ARCHITECTURE_en.md && grep -Fq \"Версия: \$ver.\" docs/ARCHITECTURE_ru.md"
run_check 0 "Shell Syntax" "for f in _Builder.sh tester.sh system/*.sh; do bash -n \"\$f\" || exit 1; done"
run_check 0 "No Global Docker Prune" "pat='(docker(\\.exe)?|podman) (network|volume|system) pr''une|run_container .* (network|volume|system) pr''une|\\$C_EXE .*system pr''une|%CONTAINER_EXE% system pr''une'; ! grep -R -E \"\$pat\" _Builder.sh _Builder.bat tester.sh tester.bat system/*.sh system/*.ps1 >/dev/null"
run_check 0 "Runtime Env Override" "tmpdir=\$(mktemp -d); trap 'rm -rf \"\$tmpdir\"' EXIT; printf '%s\n' '#!/bin/sh' 'exit 1' >\"\$tmpdir/docker\"; printf '%s\n' '#!/bin/sh' 'case \"\$1 \$2\" in' '  \"info \"|\"info\") exit 0 ;;' '  \"compose version\") exit 0 ;;' '  \"--version \"|\"--version\") echo \"podman version 5.0.0\"; exit 0 ;;' '  *) exit 0 ;;' 'esac' >\"\$tmpdir/podman\"; chmod +x \"\$tmpdir/docker\" \"\$tmpdir/podman\"; PATH=\"\$tmpdir:\$PATH\" ROUTERFW_TEST_MODE= ROUTERFW_RUNTIME=podman bash \"$SCRIPT_DIR/$SH\" help >/dev/null 2>&1"
run_check 0 "Runtime WSL Podman Bridge" "tmpdir=\$(mktemp -d); trap 'rm -rf \"\$tmpdir\"' EXIT; for tool in bash head cut tr sed dirname pwd locale cat find sort awk basename clear mktemp; do real=\$(command -v \"\$tool\" 2>/dev/null || true); [ -n \"\$real\" ] && ln -s \"\$real\" \"\$tmpdir/\$tool\" 2>/dev/null || true; done; printf '%s\n' '#!/bin/sh' 'if [ \"\$1\" = \"-qi\" ] && [ \"\$2\" = \"microsoft\" ] && [ \"\$3\" = \"/proc/version\" ]; then exit 0; fi' 'exec /usr/bin/grep \"\$@\"' >\"\$tmpdir/grep\"; printf '%s\n' '#!/bin/sh' 'case \"\$1\" in' '  info) exit 0 ;;' '  --version) echo \"podman version 5.8.3\"; exit 0 ;;' '  compose) [ \"\$2\" = \"version\" ] && { echo \"Docker Compose version v5.2.0\"; exit 0; } ;;' 'esac' 'exit 1' >\"\$tmpdir/podman.exe\"; chmod +x \"\$tmpdir/grep\" \"\$tmpdir/podman.exe\"; out=\$(PATH=\"\$tmpdir\" ROUTERFW_TEST_MODE= ROUTERFW_RUNTIME=podman ROUTERFW_NO_CLS=1 \"\$tmpdir/bash\" \"$SCRIPT_DIR/$SH\" help 2>&1); rc=\$?; test \$rc -eq 0 && printf '%s\n' \"\$out\" | \"\$tmpdir/grep\" -F 'podman + podman.exe compose' >/dev/null"
run_check 0 "Runtime Explicit Failure" "tmpdir=\$(mktemp -d); trap 'rm -rf \"\$tmpdir\"' EXIT; printf '%s\n' '#!/bin/sh' 'exit 1' >\"\$tmpdir/docker\"; cp \"\$tmpdir/docker\" \"\$tmpdir/docker.exe\"; chmod +x \"\$tmpdir/docker\" \"\$tmpdir/docker.exe\"; out=\$(PATH=\"\$tmpdir:\$PATH\" ROUTERFW_TEST_MODE= bash \"$SCRIPT_DIR/$SH\" --runtime=docker help 2>&1); rc=\$?; test \$rc -eq 1 && printf '%s\n' \"\$out\" | grep -E 'Docker (not found|не обнаружен)' >/dev/null"
run_check 0 "Compose Wrapper Docker" "log_file=\$(mktemp); trap 'rm -f \"\$log_file\"' EXIT; ROUTERFW_TEST_MODE=1 ROUTERFW_NO_CLS=1 ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml ROUTERFW_TEST_COMPOSE_ARGS='-p audit up builder-openwrt' ROUTERFW_TEST_COMPOSE_LOG=\"\$log_file\" bash \"$SCRIPT_DIR/$SH\" help >/dev/null 2>&1; line=\$(head -n 1 \"\$log_file\"); [[ \"\$line\" == 'docker compose -f system/docker-compose.yaml -p audit up builder-openwrt' ]] && [[ \"\$line\" != *'docker-compose.yaml -f system/docker-compose.yaml'* ]]"
run_check 0 "Compose Wrapper Podman" "log_file=\$(mktemp); trap 'rm -f \"\$log_file\"' EXIT; ROUTERFW_TEST_MODE=1 ROUTERFW_NO_CLS=1 ROUTERFW_RUNTIME=podman ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml ROUTERFW_TEST_COMPOSE_ARGS='-p audit up builder-openwrt' ROUTERFW_TEST_COMPOSE_LOG=\"\$log_file\" bash \"$SCRIPT_DIR/$SH\" help >/dev/null 2>&1; line=\$(head -n 1 \"\$log_file\"); [[ \"\$line\" == 'ROUTERFW_BIND_RW_SUFFIX=:z ROUTERFW_BIND_RO_SUFFIX=:ro,z ROUTERFW_BIND_PROFILES_SUFFIX=:ro,z podman-compose -f system/docker-compose.yaml -f system/podman-compose.yaml -p audit up builder-openwrt' ]] && [[ \"\$line\" != *'docker-compose.yaml -f system/docker-compose.yaml'* ]]"
run_check 0 "Compose Wrapper Docker Standalone" "log_file=\$(mktemp); trap 'rm -f \"\$log_file\"' EXIT; ROUTERFW_TEST_MODE=1 ROUTERFW_NO_CLS=1 ROUTERFW_TEST_COMPOSE_PROVIDER=standalone ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml ROUTERFW_TEST_COMPOSE_ARGS='-p audit up builder-openwrt' ROUTERFW_TEST_COMPOSE_LOG=\"\$log_file\" bash \"$SCRIPT_DIR/$SH\" help >/dev/null 2>&1; line=\$(head -n 1 \"\$log_file\"); [[ \"\$line\" == 'docker-compose -f system/docker-compose.yaml -p audit up builder-openwrt' ]]"
run_check 0 "Compose Wrapper Podman Standalone" "log_file=\$(mktemp); trap 'rm -f \"\$log_file\"' EXIT; ROUTERFW_TEST_MODE=1 ROUTERFW_NO_CLS=1 ROUTERFW_RUNTIME=podman ROUTERFW_TEST_COMPOSE_PROVIDER=standalone ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml ROUTERFW_TEST_COMPOSE_ARGS='-p audit up builder-openwrt' ROUTERFW_TEST_COMPOSE_LOG=\"\$log_file\" bash \"$SCRIPT_DIR/$SH\" help >/dev/null 2>&1; line=\$(head -n 1 \"\$log_file\"); [[ \"\$line\" == 'ROUTERFW_BIND_RW_SUFFIX=:z ROUTERFW_BIND_RO_SUFFIX=:ro,z ROUTERFW_BIND_PROFILES_SUFFIX=:ro,z podman-compose -f system/docker-compose.yaml -f system/podman-compose.yaml -p audit up builder-openwrt' ]]"

# Проверка BOM
BOM_CHECK_CMD="
  test_bom() { [[ \"\$(head -c 3 \"\$1\")\" == \$'\\xef\\xbb\\xbf' ]]; };
  errors=0;
  BOM_EXPECTED=('system/create_profile.ps1' 'system/import_ipk.ps1');
  NO_BOM_EXPECTED=('_Builder.sh' 'system/lang/ru.env' 'README.md');
  for f in \"\${BOM_EXPECTED[@]}\" \"\${NO_BOM_EXPECTED[@]}\"; do
    [ -f \"\$f\" ] || { echo \"Missing file: \$f\"; errors=1; };
  done;
  for f in \"\${BOM_EXPECTED[@]}\"; do 
    if [ -f \"\$f\" ]; then
        test_bom \"\$f\" || { echo \"BOM missing in \$f\"; ((errors++)); }; 
    fi
  done;
  for f in \"\${NO_BOM_EXPECTED[@]}\"; do 
    if [ -f \"\$f\" ]; then
        test_bom \"\$f\" && { echo \"Unexpected BOM in \$f\"; ((errors++)); }; 
    fi
  done;
  exit \$errors
"
run_check 0 "BOM Signature" "$BOM_CHECK_CMD"

wait_all
if [ "$FULL_CI" -eq 1 ] || [ ${#FILTERS[@]} -gt 0 ]; then
  for runtime in docker podman; do
    label="${runtime^} Smoke"
    enqueue_task 0 "$label" "Check" bash -e -o pipefail -c "container_smoke $runtime"
    wait_all
  done
else
  TEE_LINE='[SKIP] Real container checks: run ./tester.sh --ci (requires Docker and Podman), or select "Docker Smoke" / "Podman Smoke".' tee_line
fi
if [ "$PASS" -eq 0 ] && [ "$FAIL" -eq 0 ]; then
  TEE_LINE='[FAIL] No tests matched the supplied labels.' tee_line
  FAIL=1
fi
if [ -s "$TASK_DIR/timings" ]; then
  TEE_LINE="" tee_line
  TEE_LINE="Slowest checks (up to 5):" tee_line
  while IFS= read -r timing; do
    TEE_LINE="[TOP] $timing" tee_line
  done < <(sort -nr "$TASK_DIR/timings" | head -n 5)
fi
TEE_LINE="" tee_line
TEE_LINE="=== Итого: $PASS OK, $FAIL FAIL ===" tee_line
TEE_LINE="" tee_line
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
