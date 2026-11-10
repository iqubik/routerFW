#!/bin/bash
# file: tester.sh v1.2
#
# Автопроверка CLI _Builder.sh.
# Запуск без аргументов = все тесты.
# Запуск с аргументами = только тесты с указанными метками.
# Пример: ./tester.sh help "Localization Keys"
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
  local mutates_unpacker=0
  [[ "$label" == Packer* ]] && mutates_unpacker=1

  if [ "$mutates_unpacker" -eq 1 ]; then
    wait_all
    enqueue_task "$expect" "$label" "Check" bash -c "$cmd"
    wait_all
  else
    enqueue_task "$expect" "$label" "Check" bash -c "$cmd"
  fi
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
    "$@" > "$out" 2>&1
    printf '%s\n' "$?" > "$rc_file"
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
  local i pid label kind expect out rc_file got
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
  done

  TASK_PIDS=()
  TASK_LABELS=()
  TASK_KINDS=()
  TASK_EXPECTS=()
  TASK_OUTS=()
  TASK_RCS=()
}

TEE_LINE="" tee_line
TEE_LINE="=== CLI tester.sh (safe checks only) ===" tee_line
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
run_check 0 "Packer Roundtrip" "set -e; tmp_unpack=\$(mktemp -d); original_unpacker=\$(mktemp); cp ./_unpacker.sh \"\$original_unpacker\"; archive_file=''; trap 'cp \"\$original_unpacker\" ./_unpacker.sh; rm -f \"\$original_unpacker\"; rm -rf \"\$tmp_unpack\"; if [ -n \"\$archive_file\" ] && [ -f \"\$archive_file\" ]; then rm -f \"\$archive_file\"; fi' EXIT; before=\$(find . -maxdepth 1 -name 'routerFW_LinuxDockerBuilder_v*.tar.gz' -print | sort); printf '\n' | ROUTERFW_TEST_MODE=1 bash ./_packer.sh >/dev/null 2>&1; test -x ./_unpacker.sh; archive_file=\$(find . -maxdepth 1 -name 'routerFW_LinuxDockerBuilder_v*.tar.gz' -print | sort | grep -Fvx \"\$before\" | head -n 1 || true); cp ./_unpacker.sh \"\$tmp_unpack/_unpacker.sh\"; (cd \"\$tmp_unpack\" && bash ./_unpacker.sh >/dev/null 2>&1); for rel in system/podman-compose.yaml system/podman-compose-src.yaml system/version.env docs/01-introduction.md docs/01-introduction.en.md docs/02-digital-twin.md docs/02-digital-twin.en.md docs/03-source-build.md docs/03-source-build.en.md docs/04-adv-source-build.md docs/04-adv-source-build.en.md docs/05-patch-sys.md docs/05-patch-sys.en.md docs/06-rax3000m-emmc-flash.md docs/06-rax3000m-emmc-flash.en.md docs/07-troubleshooting-faq.md docs/07-troubleshooting-faq.en.md docs/08-ib-apk-import-embed.md docs/08-ib-apk-import-embed.en.md docs/ARCHITECTURE_ru.md docs/ARCHITECTURE_en.md docs/ARCHITECTURE_diagram_ru.md docs/ARCHITECTURE_diagram_en.md docs/map.md docs/map.en.md docs/audit.md docs/index.md docs/index.en.md; do test -f \"\$tmp_unpack/\$rel\"; cmp -s \"./\$rel\" \"\$tmp_unpack/\$rel\"; done"
run_check 0 "Packer Corrupt Unpack Fails" "set -e; tmp_unpack=\$(mktemp -d); original_unpacker=\$(mktemp); cp ./_unpacker.sh \"\$original_unpacker\"; archive_file=''; trap 'cp \"\$original_unpacker\" ./_unpacker.sh; rm -f \"\$original_unpacker\"; rm -rf \"\$tmp_unpack\"; if [ -n \"\$archive_file\" ] && [ -f \"\$archive_file\" ]; then rm -f \"\$archive_file\"; fi' EXIT; before=\$(find . -maxdepth 1 -name 'routerFW_LinuxDockerBuilder_v*.tar.gz' -print | sort); printf '\n' | ROUTERFW_TEST_MODE=1 bash ./_packer.sh >/dev/null 2>&1; archive_file=\$(find . -maxdepth 1 -name 'routerFW_LinuxDockerBuilder_v*.tar.gz' -print | sort | grep -Fvx \"\$before\" | head -n 1 || true); awk 'BEGIN{inblk=0;done=0} \$0==\"# BEGIN_B64_ system/version.env\"{inblk=1;print;next} \$0==\"# END_B64_ system/version.env\"{inblk=0;print;next} inblk && !done && \$0 !~ /^#/{print \"!!!!\"; done=1; next} {print} END{exit done?0:1}' ./_unpacker.sh > \"\$tmp_unpack/_unpacker.sh\"; (cd \"\$tmp_unpack\" && ! bash ./_unpacker.sh >/dev/null 2>&1); test ! -f \"\$tmp_unpack/system/version.env\""

# Проверка BOM
BOM_CHECK_CMD="
  test_bom() { [[ \"\$(head -c 3 \"\$1\")\" == \$'\\xef\\xbb\\xbf' ]]; };
  errors=0;
  BOM_EXPECTED=('system/create_profile.ps1' 'system/import_ipk.ps1');
  NO_BOM_EXPECTED=('_Builder.sh' 'system/lang/ru.env' 'README.md');
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
TEE_LINE="" tee_line
TEE_LINE="=== Итого: $PASS OK, $FAIL FAIL ===" tee_line
TEE_LINE="" tee_line
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
