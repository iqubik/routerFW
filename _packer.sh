#!/bin/bash
# file: _packer.sh
set -o pipefail

PACKER_VER="2.7MT"
# Multi-threaded Base64 Resource Storage (checksum). Версия: PACKER_VER
bash ./_Builder.sh check-all
echo -e "${C_LBL}========================================${C_RST}"
if [ -z "${ROUTERFW_TEST_MODE:-}" ]; then
    read -p "Press Enter to start packing (v${PACKER_VER} SH)..."
fi
# Гарантируем работу в папке скрипта
cd "$(dirname "$0")"

# Настройка цветов
C_LBL='\033[36m'
C_OK='\033[92m'
C_ERR='\033[91m'
C_RST='\033[0m'

if [ -z "${ROUTERFW_TEST_MODE:-}" ]; then
    clear
fi
echo -e "${C_LBL}========================================${C_RST}"
echo -e "  OpenWrt Packer (v${PACKER_VER} Linux)"
echo -e "${C_LBL}========================================${C_RST}"
echo ""

# --- 1. Список файлов для упаковки ---
FILES=(
# --- Основные файлы ---
    "system/openssl.cnf"
    "system/docker-compose.yaml"
    "system/docker-compose-src.yaml"
    "system/podman-compose.yaml"
    "system/podman-compose-src.yaml"
    "system/ib_builder.sh"
    "system/src_builder.sh"
    "system/overlay_permissions.sh"
    "system/dockerfile"
    "system/dockerfile.legacy"
    "system/src.dockerfile"
    "system/src.dockerfile.legacy"
    "system/create_profile.sh"
    "system/import_ipk.sh"
    "system/apk_scanner.sh"
    "system/version.env"
    "system/lang/ru.env"
    "system/lang/en.env"
    "scripts/show_pkgs.sh"
    "_Builder.sh"
# --- Документация ---
    "README.md"
    "README.en.md"
    "docs/01-introduction.md"
    "docs/01-introduction.en.md"
    "docs/02-digital-twin.md"
    "docs/02-digital-twin.en.md"
    "docs/03-source-build.md"
    "docs/03-source-build.en.md"
    "docs/04-adv-source-build.md"
    "docs/04-adv-source-build.en.md"
    "docs/05-patch-sys.md"
    "docs/05-patch-sys.en.md"
    "docs/06-rax3000m-emmc-flash.md"
    "docs/06-rax3000m-emmc-flash.en.md"
    "docs/07-troubleshooting-faq.md"
    "docs/07-troubleshooting-faq.en.md"
    "docs/08-ib-apk-import-embed.md"
    "docs/08-ib-apk-import-embed.en.md"
    "docs/09-file-permissions.md"
    "docs/09-file-permissions.en.md"
    "docs/ARCHITECTURE_ru.md"
    "docs/ARCHITECTURE_en.md"
    "docs/ARCHITECTURE_diagram_ru.md"
    "docs/ARCHITECTURE_diagram_en.md"
    "docs/map.md"
    "docs/map.en.md"
    "docs/audit.md"
    "docs/index.md"
    "docs/index.en.md"
# --- ЗАЩИЩЕННЫЕ ОБЪЕКТЫ ---
    "scripts/etc/uci-defaults/99-permissions.sh"
    "scripts/diag.sh"
    "scripts/hooks.sh"
    "scripts/upgrade.sh"
    "scripts/packager.sh"
    "profiles/giga_24105_main_full.conf"
    "profiles/rax3000m_emmc_test_new.conf"
    "profiles/tplink_841n_v9_190710_full.conf"
    "profiles/friendlyarm_nanopi_r3s_24105_ow_full.conf"
    "custom_files/rax3000m_emmc_test_new/hooks.sh"
)

TEMP_DIR="temp_packer_sh"
NEW_UNPACKER="_unpacker.sh"

cleanup() {
    rm -rf "$TEMP_DIR"
}

# Очистка
rm -f "$NEW_UNPACKER"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# --- 2. Генерация шапки распаковщика ---
echo -e "[PACKER] Создание структуры распаковщика..."

{
    echo "#!/bin/bash"
    echo "# =========================================================
#  Unpacker (Smart Edition v${PACKER_VER} SH)
# ========================================================="
    echo ""
    echo "# Переходим в директорию скрипта"
} > "$NEW_UNPACKER"
cat << 'EOF' >> "$NEW_UNPACKER"
set -e

cd "$(dirname "$0")"

echo "[UNPACKER] Resource check..."

SKIP_DEFAULTS=0
if [ -f "profiles/personal.flag" ]; then
    echo "[INFO] Personal installation detected. Preserving protected files; repairing core files only when ROUTERFW_REPAIR=1."
    SKIP_DEFAULTS=1
fi

decode_file() {
    local target="$1"
    local hash="$2"
    local actual_hash
    local tmp

    if [ -f "$target" ]; then
        if [ -n "$hash" ] && [ "$hash" != "unknown" ]; then
            actual_hash=$(md5sum "$target" | cut -d' ' -f1)
            actual_hash="${actual_hash,,}"
            if [ "$actual_hash" = "$hash" ]; then
                return 0
            fi
            if [ "${ROUTERFW_REPAIR:-0}" != "1" ]; then
                echo "[WARN] Modified file preserved: $target"
                return 0
            fi
            echo "[WARN] Existing checksum mismatch, repairing: $target"
            cp -p -- "$target" "${target}.routerfw.bak" 2>/dev/null || cp -- "$target" "${target}.routerfw.bak"
        else
            return 0
        fi
    fi

    echo "[UNPACK] Recover: $target - md5( $hash )"

    tmp=$(mktemp) || return 1

    # Извлекаем Base64 блок между маркерами во временный файл.
    # FIX: Используем строгое равенство (==) вместо match (~), 
    # чтобы избежать совпадения имен файлов (например, dockerfile и dockerfile.legacy)
    if ! awk -v t="$target" '$0 == "# BEGIN_B64_ " t, $0 == "# END_B64_ " t' "$0" | \
        grep -v "BEGIN_B64_" | grep -v "END_B64_" | base64 -d > "$tmp"; then
        rm -f "$tmp"
        echo "[ERROR] Failed to decode: $target"
        return 1
    fi

    if [ -n "$hash" ] && [ "$hash" != "unknown" ]; then
        actual_hash=$(md5sum "$tmp" | cut -d' ' -f1)
        actual_hash="${actual_hash,,}"
        if [ "$actual_hash" != "$hash" ]; then
            rm -f "$tmp"
            echo "[ERROR] Checksum mismatch: $target"
            echo "[ERROR] Expected: $hash"
            echo "[ERROR] Actual:   $actual_hash"
            return 1
        fi
    fi

    mkdir -p "$(dirname "$target")"
    mv "$tmp" "$target"

    # Если это скрипт - даем права на исполнение
    if [[ "$target" == *.sh ]]; then
        chmod +x "$target"
    fi
}

EOF

# --- 3. Многопоточное кодирование ---
echo -e "[PACKER] Запуск потоков кодирования (${#FILES[@]} файлов)..."

# Возвращает префикс комментария для строки checksum
checksum_comment_prefix() {
    local path="$1"
    local ext="${path##*.}"
    [[ "$ext" == "bat" || "$ext" == "cmd" ]] && echo "::" || echo "#"
}

# Функция воркера
process_file() {
    local file="$1"
    local id="$2"
    local temp_dir="$3"
    local out="$temp_dir/$id.chunk"
    local ready="$temp_dir/$id.ready"
    local staged="$temp_dir/$id.staged"
    local hash_out="$temp_dir/$id.md5"

    if [ ! -f "$file" ]; then
        echo -e "${C_ERR}   [ERROR] Required file '$file' not found.${C_RST}" >&2
        return 1
    fi

    # Подготовка файла (Оригинальная логика AWK)
    # Удаляет BOM, CRLF и старый checksum
    if ! awk '
        BEGIN { has_cr = 0 }
        {
            if (NR == 1 && /\r$/) has_cr = 1;
            sub(/\r$/, "");
            lines[NR] = $0;
        }
        END {
            last = NR;
            while (last > 0) {
                if (lines[last] ~ /^[ \t]*$/) {
                    last--;
                } else if (lines[last] ~ /^[ \t]*(::|#)?[ \t]*checksum:MD5=[0-9a-fA-F]{32}[ \t]*$/) {
                    last--;
                } else {
                    break;
                }
            }
            eol = has_cr ? "\r\n" : "\n";
            for (i = 1; i <= last; i++) {
                printf "%s%s", lines[i], eol;
            }
        }' "$file" > "$staged"; then
        rm -f "$staged"
        echo -e "${C_ERR}   [ERROR] Failed to stage '$file'.${C_RST}" >&2
        return 1
    fi

    # Считаем хеш (для staged версии без checksum строки)
    local hash
    if ! hash=$(md5sum < "$staged" | cut -d' ' -f1); then
        rm -f "$staged"
        echo -e "${C_ERR}   [ERROR] Failed to hash '$file'.${C_RST}" >&2
        return 1
    fi
    hash="${hash,,}"

    local prefix
    prefix=$(checksum_comment_prefix "$file")

    # Дописываем новую checksum строку
    if ! printf '%s checksum:MD5=%s' "$prefix" "$hash" >> "$staged"; then
        rm -f "$staged"
        echo -e "${C_ERR}   [ERROR] Failed to append checksum for '$file'.${C_RST}" >&2
        return 1
    fi

    # Распаковщик проверяет целостность фактически встроенного payload.
    local payload_hash
    if ! payload_hash=$(md5sum < "$staged" | cut -d' ' -f1); then
        rm -f "$staged"
        echo -e "${C_ERR}   [ERROR] Failed to hash payload for '$file'.${C_RST}" >&2
        return 1
    fi
    payload_hash="${payload_hash,,}"
    if ! echo "$payload_hash" > "$hash_out"; then
        rm -f "$staged"
        echo -e "${C_ERR}   [ERROR] Failed to write payload hash for '$file'.${C_RST}" >&2
        return 1
    fi

    {
        echo ""
        echo "# BEGIN_B64_ $file"
        base64 "$staged"
        echo "# END_B64_ $file"
    } > "$out"
    local rc=$?
    rm -f "$staged"
    if [ "$rc" -ne 0 ]; then
        rm -f "$out"
        echo -e "${C_ERR}   [ERROR] Failed to encode '$file'.${C_RST}" >&2
        return 1
    fi

    # Сигнализируем о готовности
    touch "$ready" || return 1
}

# Запуск процессов в фоне
pids=()
for i in "${!FILES[@]}"; do
    (
        process_file "${FILES[$i]}" "$i" "$TEMP_DIR"
        rc=$?
        touch "$TEMP_DIR/$i.ready" 2>/dev/null || true
        exit "$rc"
    ) &
    pids+=("$!")
done

# Цикл ожидания прогресса
TOTAL=${#FILES[@]}
while true; do
    DONE=$(ls -1 "$TEMP_DIR"/*.ready 2>/dev/null | wc -l)
    echo -ne "\r[PACKER] Progress: $DONE / $TOTAL   "
    if [ "$DONE" -ge "$TOTAL" ]; then
        break
    fi
    sleep 0.2
done
echo ""

worker_failed=0
for pid in "${pids[@]}"; do
    wait "$pid" || worker_failed=1
done

if [ "$worker_failed" -ne 0 ]; then
    echo -e "${C_ERR}[ERROR] One or more packer workers failed.${C_RST}" >&2
    cleanup
    exit 1
fi

echo -e "[PACKER] Все потоки завершены. Генерация логики и сборка..."

# --- 4. Финализация распаковщика ---

# 4.1 Генерация вызовов функций
for i in "${!FILES[@]}"; do
    FILE="${FILES[$i]}"
    HASH_FILE="$TEMP_DIR/$i.md5"
    
    if [ ! -f "$HASH_FILE" ]; then
        echo -e "${C_ERR}[ERROR] Missing worker hash: $HASH_FILE${C_RST}" >&2
        cleanup
        exit 1
    fi
    F_HASH=$(cat "$HASH_FILE")

    IS_PROTECTED=0
    [[ "$FILE" == profiles/* ]] && IS_PROTECTED=1
    [[ "$FILE" == firmware_output/* ]] && IS_PROTECTED=1
    [[ "$FILE" == custom_files/* ]] && IS_PROTECTED=1
    [[ "$FILE" == scripts/* ]] && IS_PROTECTED=1

    if [ $IS_PROTECTED -eq 1 ]; then
        echo "if [ \$SKIP_DEFAULTS -eq 0 ]; then decode_file \"$FILE\" \"$F_HASH\" || exit 1; fi" >> "$NEW_UNPACKER"
    else
        echo "decode_file \"$FILE\" \"$F_HASH\" || exit 1" >> "$NEW_UNPACKER"
    fi
done

# 4.2 Завершение скрипта
cat << 'EOF' >> "$NEW_UNPACKER"

mkdir -p profiles
if [ ! -f "profiles/personal.flag" ]; then
    echo "Initial setup done" > "profiles/personal.flag"
    echo "[INFO] Created flag profiles/personal.flag"
fi

echo "[UNPACKER] Complete."
echo "==================================="
echo "Now you will Run ./_Builder.sh"
echo "==================================="
exit 0

# =========================================================
# BASE64 DATA
# =========================================================
EOF

# 4.3 Прикрепление данных
for i in "${!FILES[@]}"; do
    if [ -f "$TEMP_DIR/$i.chunk" ]; then
        cat "$TEMP_DIR/$i.chunk" >> "$NEW_UNPACKER"
    else
        echo -e "${C_ERR}[ERROR] Missing worker chunk: $TEMP_DIR/$i.chunk${C_RST}" >&2
        cleanup
        exit 1
    fi
done

# Делаем распаковщик исполняемым
chmod +x "$NEW_UNPACKER"

# Удаляем временную папку
cleanup

# --- 5. Создание архива ---
ZIP_DATE=$(date +"%d.%m.%Y_%H-%M")
ARCHIVE_NAME="routerFW_LinuxDockerBuilder_v$ZIP_DATE.tar.gz"

echo -e "[PACKER] Создание архива $ARCHIVE_NAME..."
tar -czf "$ARCHIVE_NAME" "$NEW_UNPACKER" || {
    echo -e "${C_ERR}[ERROR] Failed to create archive: $ARCHIVE_NAME${C_RST}" >&2
    exit 1
}

echo -e "${C_OK}========================================${C_RST}"
echo -e "  Файл обновлен: $NEW_UNPACKER"
echo -e "  Архив создан:  $ARCHIVE_NAME"
echo -e "  ГОТОВО (v${PACKER_VER} SH)"
echo -e "${C_OK}========================================${C_RST}"
