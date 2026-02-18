#!/bin/bash
# file: _packer.sh
# Multi-threaded Base64 Resource Storage (Parity v2.1)

# Гарантируем работу в папке скрипта
cd "$(dirname "$0")"

# Настройка цветов
C_LBL='\033[36m'
C_OK='\033[92m'
C_ERR='\033[91m'
C_RST='\033[0m'

clear
echo -e "${C_LBL}========================================${C_RST}"
echo -e "  OpenWrt Packer (v2.1 MT Linux)"
echo -e "${C_LBL}========================================${C_RST}"
echo ""

# --- 1. Список файлов для упаковки ---
# Синхронизировано с .bat версией
FILES=(
    "system/openssl.cnf"
    "system/docker-compose.yaml"
    "system/docker-compose-src.yaml"
    "system/ib_builder.sh"
    "system/src_builder.sh"
    "system/dockerfile"
    "system/dockerfile.legacy"
    "system/src.dockerfile"
    "system/src.dockerfile.legacy"
    "system/create_profile.sh"
    "system/import_ipk.sh"
    "system/lang/ru.env"
    "system/lang/en.env"
    "scripts/show_pkgs.sh"
    "_Builder.sh"
    "README.md"
    "README.en.md"
    "docs/01-introduction.md"
    "docs/02-digital-twin.md"
    "docs/03-source-build.md"
    "docs/04-adv-source-build.md"
    "docs/index.md"
    "docs/01-introduction.en.md"
    "docs/02-digital-twin.en.md"
    "docs/03-source-build.en.md"
    "docs/04-adv-source-build.en.md"
    "docs/05-patch-sys.md"
    "docs/05-patch-sys.en.md"
    "docs/index.en.md"
    "scripts/etc/uci-defaults/99-permissions.sh"
    "scripts/diag.sh"
    "scripts/hooks.sh"
    "scripts/upgrade.sh"
    "scripts/packager.sh"
    "profiles/giga_24105_main_full.conf"
    "profiles/rax3000m_emmc_test_new.conf"
    "profiles/xiaomi_4a_gigabit_23056_full.conf"
    "profiles/tplink_841n_v9_190710_full.conf"
    "profiles/friendlyarm_nanopi_r3s_24105_ow_full.conf"
    "custom_files/rax3000m_emmc_test_new/hooks.sh"
)

TEMP_DIR="temp_packer_sh"
NEW_UNPACKER="_unpacker.sh"

# Очистка
rm -f "$NEW_UNPACKER"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# --- 2. Генерация логики распаковщика ---
echo -e "[PACKER] Создание логики распаковщика..."

cat << 'EOF' > "$NEW_UNPACKER"
#!/bin/bash
# =========================================================
#  Unpacker (Smart Edition v2.1 SH)
# =========================================================

# Переходим в директорию скрипта
cd "$(dirname "$0")"

echo "[UNPACKER] Resource check..."

SKIP_DEFAULTS=0
if [ -f "profiles/personal.flag" ]; then
    echo "[INFO] Found personal.flag. Recovering protected files only."
    SKIP_DEFAULTS=1
fi

decode_file() {
    local target="$1"
    # Если файл существует - пропускаем
    if [ -f "$target" ]; then return; fi
    
    # Создаем папку
    mkdir -p "$(dirname "$target")"
    echo "[UNPACK] Recover: $target"
    
    # Извлекаем Base64 блок между маркерами
    # Используем awk для точного парсинга текущего файла ($0)
    awk -v t="$target" '$0 ~ "# BEGIN_B64_ " t, $0 ~ "# END_B64_ " t' "$0" | \
    grep -v "BEGIN_B64_" | grep -v "END_B64_" | base64 -d > "$target"
    
    # Если это скрипт - даем права на исполнение
    if [[ "$target" == *.sh ]]; then
        chmod +x "$target"
    fi
}

EOF

# Добавляем вызовы функций в распаковщик (Определяем защищенные файлы)
for f in "${FILES[@]}"; do
    IS_PROTECTED=0
    [[ "$f" == profiles/* ]] && IS_PROTECTED=1
    [[ "$f" == firmware_output/* ]] && IS_PROTECTED=1
    [[ "$f" == scripts/* ]] && IS_PROTECTED=1

    if [ $IS_PROTECTED -eq 1 ]; then
        echo "if [ \$SKIP_DEFAULTS -eq 0 ]; then decode_file \"$f\"; fi" >> "$NEW_UNPACKER"
    else
        echo "decode_file \"$f\"" >> "$NEW_UNPACKER"
    fi
done

# Завершение логики распаковщика
cat << 'EOF' >> "$NEW_UNPACKER"

mkdir -p profiles
if [ ! -f "profiles/personal.flag" ]; then
    echo "Initial setup done" > "profiles/personal.flag"
    echo "[INFO] Created flag profiles/personal.flag"
fi

echo "[UNPACKER] Complete."
echo "==================================="
echo "Run ./_Builder.sh"
echo "==================================="
exit 0

# =========================================================
# BASE64 DATA
# =========================================================
EOF

# --- 3. Многопоточное кодирование ---
echo -e "[PACKER] Запуск потоков кодирования (${#FILES[@]} файлов)..."

# Функция воркера (будет запущена в подоболочке)
process_file() {
    local file="$1"
    local id="$2"
    local temp_dir="$3"
    local out="$temp_dir/$id.chunk"
    local ready="$temp_dir/$id.ready"

    if [ -f "$file" ]; then
        echo "" > "$out"
        echo "# BEGIN_B64_ $file" >> "$out"
        base64 "$file" >> "$out"
        echo "# END_B64_ $file" >> "$out"
    else
        # Заглушка, если файла нет (чтобы не ломать структуру)
        echo "" > "$out" 
        echo -e "${C_ERR}   [SKIP] Файл '$file' не найден.${C_RST}"
    fi
    # Сигнализируем о готовности
    touch "$ready"
}

# Запуск процессов в фоне
for i in "${!FILES[@]}"; do
    # Запускаем в фоне (&)
    process_file "${FILES[$i]}" "$i" "$TEMP_DIR" &
done

# Цикл ожидания с прогресс-баром
TOTAL=${#FILES[@]}
while true; do
    DONE=$(ls -1 "$TEMP_DIR"/*.ready 2>/dev/null | wc -l)
    
    # Рисуем прогресс
    echo -ne "\r[PACKER] Progress: $DONE / $TOTAL   "
    
    if [ "$DONE" -ge "$TOTAL" ]; then
        break
    fi
    sleep 0.2
done
echo ""

echo -e "[PACKER] Все потоки завершены. Сборка финального файла..."

# --- 4. Сборка и финализация ---
for i in "${!FILES[@]}"; do
    if [ -f "$TEMP_DIR/$i.chunk" ]; then
        cat "$TEMP_DIR/$i.chunk" >> "$NEW_UNPACKER"
    fi
done

# Делаем распаковщик исполняемым
chmod +x "$NEW_UNPACKER"

# Удаляем временную папку
rm -rf "$TEMP_DIR"

# --- 5. Создание архива (tar.gz для Linux) ---
ZIP_DATE=$(date +"%d.%m.%Y_%H-%M")
ARCHIVE_NAME="routerFW_LinuxDockerBuilder_v$ZIP_DATE.tar.gz"

echo -e "[PACKER] Создание архива $ARCHIVE_NAME..."
tar -czf "$ARCHIVE_NAME" "$NEW_UNPACKER"

echo -e "${C_OK}========================================${C_RST}"
echo -e "  Файл обновлен: $NEW_UNPACKER"
echo -e "  Архив создан:  $ARCHIVE_NAME"
echo -e "  ГОТОВО (v2.1 SH MT)"
echo -e "${C_OK}========================================${C_RST}"