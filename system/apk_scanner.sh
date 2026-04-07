#!/bin/bash
# file : system/apk_scanner.sh
# Скрипт сканирования и валидации APK-пакетов в custom_packages

SCRIPT_VERSION="1.0"

# --- ПАРАМЕТРЫ ---
PROFILE_ID="${1:-}"
TARGET_ARCH="${2:-}"

# --- ЦВЕТА ---
C_CYAN='\033[0;36m'
C_YEL='\033[1;33m'
C_RED='\033[0;31m'
C_GRN='\033[0;32m'
C_GRY='\033[0;90m'
C_WHT='\033[1;37m'
C_RST='\033[0m'

# --- ЯЗЫК (автоопределение) ---
IS_RU=false
[ "${APK_SCANNER_LANG^^}" == "RU" ] && IS_RU=true

# Словарь
if [ "$IS_RU" = true ]; then
    T_SCAN_TITLE="APK СКАНЕР"
    T_SCANNING="Сканирую APK в..."
    T_NO_FILES="APK-файлы не найдены."
    T_HEADER="ПАКЕТ"
    T_PARSE_FAIL="Ошибка чтения метаданных"
    T_ARCH_UNIV="Универсальная"
    T_ARCH_MATCH="Совпадение"
    T_ARCH_WARN="⚠ НЕСОВПАДЕНИЕ АРХИТЕКТУРЫ"
    T_ARCH_WARN_DETAIL="Пакет имеет архитектуру, отличную от профиля"
    T_NAME_OK="Имя соответствует"
    T_NAME_WARN="⚠ НЕСООТВЕТСТВИЕ ИМЕНИ"
    T_NAME_FILE="  Имя файла   :"
    T_NAME_INTERNAL="  Внутреннее  :"
    T_RENAME_PROMPT="  Переименовать? [Y/n]: "
    T_RENAMED="  ✓ Переименован в"
    T_SKIPPED="  Пропущено"
    T_DONE="ГОТОВО: проверено %d, переименовано %d, предупреждений %d"
else
    T_SCAN_TITLE="APK SCANNER"
    T_SCANNING="Scanning APKs in..."
    T_NO_FILES="No APK files found."
    T_HEADER="PACKAGE"
    T_PARSE_FAIL="Metadata parse failed"
    T_ARCH_UNIV="Universal"
    T_ARCH_MATCH="Match"
    T_ARCH_WARN="⚠ ARCHITECTURE MISMATCH"
    T_ARCH_WARN_DETAIL="Package architecture differs from profile target"
    T_NAME_OK="Name matches"
    T_NAME_WARN="⚠ NAME MISMATCH"
    T_NAME_FILE="  Filename   :"
    T_NAME_INTERNAL="  Internal   :"
    T_RENAME_PROMPT="  Rename? [Y/n]: "
    T_RENAMED="  ✓ Renamed to"
    T_SKIPPED="  Skipped"
    T_DONE="DONE: %d scanned, %d renamed, %d warnings"
fi

# --- ФУНКЦИИ ---
log_header() {
    echo -e "${C_CYAN}==========================================================${C_RST}"
    echo -e "  $T_SCAN_TITLE v$SCRIPT_VERSION"
    echo -e "${C_CYAN}==========================================================${C_RST}"
}

log_info() {
    echo -e "    ${C_GRY}[INFO]${C_RST} $1"
}

log_ok() {
    echo -e "    ${C_GRN}[OK]${C_RST} $1"
}

log_warn() {
    echo -e "    ${C_YEL}[WARN]${C_RST} $1"
}

log_error() {
    echo -e "    ${C_RED}[ERR]${C_RST} $1"
}

# --- ПУТИ ---
if [ -n "$PROFILE_ID" ]; then
    APK_DIR="custom_packages/$PROFILE_ID"
else
    APK_DIR="custom_packages"
fi

log_header
echo -e " [TARGET]  ${C_GRY}Profile: ${C_WHT}${PROFILE_ID:-GLOBAL}${C_RST}"
echo -e "           ${C_GRY}Arch   : ${C_WHT}${TARGET_ARCH:-NOT DEFINED}${C_RST}"
echo -e " [PATHS]   ${C_GRY}Source : ${C_WHT}$APK_DIR${C_RST}"
echo -e "${C_CYAN}==========================================================${C_RST}"

# --- ПРОВЕРКА ---
if [ ! -d "$APK_DIR" ]; then
    echo -e "${C_YEL}[!] $APK_DIR not found.${C_RST}"
    exit 0
fi

shopt -s nullglob
APK_FILES=("$APK_DIR"/*.apk)
shopt -u nullglob

if [ ${#APK_FILES[@]} -eq 0 ]; then
    echo -e "${C_GRN}[+] $T_NO_FILES${C_RST}"
    exit 0
fi

echo -e "${C_CYAN}[*] $T_SCANNING $APK_DIR (${#APK_FILES[@]} files)${C_RST}"
echo ""

SCANNED=0
RENAMED=0
WARNINGS=0

for APK_PATH in "${APK_FILES[@]}"; do
    APK_NAME=$(basename "$APK_PATH")
    echo -e "${C_CYAN}[${SCANNED}] ${APK_NAME}${C_RST}"

    # --- 1. Docker adbdump ---
    APK_ABS_DIR=$(cd "$(dirname "$APK_PATH")" && pwd)
    APK_FILE=$(basename "$APK_PATH")

    ADBDUMP_OUT=$(docker run --rm -v "$APK_ABS_DIR:/data" alpine:latest apk adbdump "/data/$APK_FILE" 2>/dev/null)

    if [ -z "$ADBDUMP_OUT" ]; then
        log_error "$T_PARSE_FAIL: $APK_NAME"
        ((WARNINGS++))
        echo ""
        ((SCANNED++))
        continue
    fi

    PKG_NAME=$(echo "$ADBDUMP_OUT" | grep -m 1 "^  name: " | sed 's/.*name: //' | tr -d '\r')
    PKG_VERSION=$(echo "$ADBDUMP_OUT" | grep -m 1 "^  version: " | sed 's/.*version: //' | tr -d '\r')
    PKG_ARCH=$(echo "$ADBDUMP_OUT" | grep -m 1 "^  arch: " | sed 's/.*arch: //' | tr -d '\r')

    if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ]; then
        log_error "$T_PARSE_FAIL: $APK_NAME (empty name/version)"
        ((WARNINGS++))
        echo ""
        ((SCANNED++))
        continue
    fi

    # --- 2. Проверка имени файла ---
    # Ожидаемый формат: {name}-{version}.apk
    # Извлекаем версию из имени файла (всё после последнего '-')
    FILE_BASE="${APK_NAME%.apk}"

    # Пытаемся найти версию в имени файла
    EXPECTED_NAME=""
    EXPECTED_VER=""
    if [[ "$FILE_BASE" =~ ^(.*)-([0-9].*)$ ]]; then
        EXPECTED_NAME="${BASH_REMATCH[1]}"
        EXPECTED_VER="${BASH_REMATCH[2]}"
    else
        EXPECTED_NAME="$FILE_BASE"
        EXPECTED_VER=""
    fi

    # Сравниваем с метаданными
    NAME_MISMATCH=false
    if [ "$EXPECTED_NAME" != "$PKG_NAME" ]; then
        NAME_MISMATCH=true
    fi
    # Для версии сравниваем только если она есть в имени файла
    if [ -n "$EXPECTED_VER" ] && [ "$EXPECTED_VER" != "$PKG_VERSION" ]; then
        NAME_MISMATCH=true
    fi

    if [ "$NAME_MISMATCH" = true ]; then
        echo -e "    ${C_YEL}--- $T_NAME_WARN ---${C_RST}"
        echo -e "${T_NAME_FILE} $APK_NAME"
        echo -e "${T_NAME_INTERNAL} ${PKG_NAME}-${PKG_VERSION}"

        # Формируем корректное имя
        CORRECT_NAME="${PKG_NAME}-${PKG_VERSION}.apk"
        CORRECT_PATH="$APK_DIR/$CORRECT_NAME"

        if [ "$CORRECT_NAME" != "$APK_NAME" ]; then
            if [ "$IS_RU" = true ]; then
                echo -ne "${T_RENAME_PROMPT}"
            else
                echo -ne "${T_RENAME_PROMPT}"
            fi
            read -r choice
            if [[ "$choice" =~ ^[Nn]$ ]]; then
                echo -e "    ${C_GRY}  $T_SKIPPED${C_RST}"
                ((WARNINGS++))
            else
                if mv "$APK_PATH" "$CORRECT_PATH"; then
                    echo -e "    ${C_GRN}${T_RENAMED} $CORRECT_NAME${C_RST}"
                    ((RENAMED++))
                else
                    log_error "Failed to rename $APK_NAME"
                    ((WARNINGS++))
                fi
            fi
        fi
    else
        log_ok "$T_NAME_OK"
    fi

    # --- 3. Проверка архитектуры ---
    if [ "$PKG_ARCH" == "all" ] || [ "$PKG_ARCH" == "noarch" ]; then
        log_ok "$T_ARCH_UNIV ($PKG_ARCH)"
    elif [ -n "$TARGET_ARCH" ]; then
        if [ "$PKG_ARCH" == "$TARGET_ARCH" ]; then
            log_ok "$T_ARCH_MATCH ($PKG_ARCH)"
        else
            log_warn "$T_ARCH_WARN"
            log_warn "$T_ARCH_WARN_DETAIL: $PKG_ARCH vs $TARGET_ARCH"
            ((WARNINGS++))
        fi
    else
        log_info "$PKG_ARCH (unchecked)"
    fi

    echo ""
    ((SCANNED++))
done

echo -e "${C_CYAN}==========================================================${C_RST}"
printf "${T_DONE}\n" "$SCANNED" "$RENAMED" "$WARNINGS"
echo -e "${C_CYAN}==========================================================${C_RST}"

# Язык для паузы (передаётся от билдера)
if [ "${APK_SCANNER_LANG^^}" == "RU" ]; then
    echo -ne "\n Нажмите Enter..."
else
    echo -ne "\n Press Enter..."
fi
read -r

if [ "$WARNINGS" -gt 0 ]; then
    exit 1
fi
exit 0
# checksum:MD5=a7bc6a1f4b9854c1c8e741fa0356992d