#!/bin/bash

# file: _packer.sh
# =========================================================
#  OpenWrt Universal Packer (v2.1 MT SH-Edition)
#  Multi-threaded Base64 Resource Storage
# =========================================================

# Настройка цветов
C_LBL='\033[36m'
C_OK='\033[92m'
C_ERR='\033[91m'
C_RST='\033[0m'

clear
echo -e "${C_LBL}========================================${C_RST}"
echo -e "  OpenWrt Universal Packer (v2.1 MT SH)"
echo -e "${C_LBL}========================================${C_RST}"
echo ""

# --- 1. Список файлов для упаковки ---
FILES=(
    "system/openssl.cnf"
    "system/docker-compose.yaml"
    "system/docker-compose-src.yaml"
    "system/dockerfile"
    "system/dockerfile.legacy"
    "system/src.dockerfile"
    "system/src.dockerfile.legacy"
    "system/create_profile.sh"
    "system/import_ipk.sh"
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
    "docs/index.en.md"
    "scripts/etc/uci-defaults/99-permissions.sh"
    "scripts/diag.sh"
    "scripts/hooks.sh"
    "scripts/upgrade.sh"
    "scripts/packager.sh"
    "profiles/giga_24105_main_full.conf"
    "profiles/giga_24105_rep_full.conf"
    "profiles/nanopi_r5c_full.conf"
    "profiles/tplink_841n_v9_190710_full.conf"
    "profiles/zbt_wr8305rt_22037_full.conf"
    "profiles/xiaomi_4a_gigabit_23056_full.conf"
    "profiles/rax3000m_i_24104_full.conf"
    "profiles/rax3000m_emmc_test_new.conf"
    "profiles/giga_24104_immortal_full.conf"
    "firmware_output/sourcebuilder/rax3000m_emmc_test_new/manual_config"
)

TEMP_DIR="temp_packer_sh"
NEW_UNPACKER="_unpacker.sh.new"

# Очистка
rm -f "$NEW_UNPACKER"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# --- 2. Генерация логики распаковщика ---
echo -e "[PACKER] Создание логики распаковщика..."

cat << 'EOF' > "$NEW_UNPACKER"
#!/bin/bash
# =========================================================
#  Универсальный распаковщик (Smart Edition v2.1 SH)
# =========================================================

echo "[UNPACKER] Проверка ресурсов..."

SKIP_DEFAULTS=0
if [ -f "profiles/personal.flag" ]; then
    echo "[INFO] Найден файл personal.flag. Пользовательские данные не будут перезаписаны."
    SKIP_DEFAULTS=1
fi

decode_file() {
    local target="$1"
    if [ -f "$target" ]; then return; fi
    
    mkdir -p "$(dirname "$target")"
    echo "[UNPACK] Восстановление: $target"
    
    # Извлечение блока Base64 и декодирование
    sed -n "/# BEGIN_B64_ $target/,/# END_B64_ $target/p" "$0" | \
    grep -v "BEGIN_B64_" | grep -v "END_B64_" | base64 -d > "$target"        
    if [[ "$target" == *.sh ]]; then
        chmod +x "$target"
    fi
}

EOF

# Добавляем вызовы функций в распаковщик
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

# Завершение логики
cat << 'EOF' >> "$NEW_UNPACKER"

mkdir -p profiles
if [ ! -f "profiles/personal.flag" ]; then
    echo "Initial setup done" > "profiles/personal.flag"
    echo "[INFO] Создан флаг profiles/personal.flag"
fi

echo "[UNPACKER] Готово."
echo "==================================="
echo "Можно запускать ./_Builder.sh"
echo "==================================="
exit 0

# =========================================================
#  СЕКЦИЯ ДАННЫХ (BASE64)
# =========================================================
EOF

# --- 3. Многопоточное кодирование ---
echo -e "[PACKER] Запуск потоков кодирования (${#FILES[@]} файлов)..."

encode_worker() {
    local file="$1"
    local id="$2"
    local out="$TEMP_DIR/$id.chunk"

    if [ -f "$file" ]; then
        echo "" > "$out"
        echo "# BEGIN_B64_ $file" >> "$out"
        base64 "$file" >> "$out"
        echo "# END_B64_ $file" >> "$out"
    else
        echo -e "  ${C_ERR}[SKIP]${C_RST} Файл '$file' не найден."
        touch "$out"
    fi
    # ВОТ ЭТОЙ СТРОКИ НЕ ХВАТАЕТ:
    touch "$TEMP_DIR/$id.ready"
}

# Запуск воркеров в фоновом режиме
for i in "${!FILES[@]}"; do
    encode_worker "${FILES[$i]}" "$i" &
done

# Ожидание завершения всех фоновых процессов
# Вместо простого wait
echo -n "[PACKER] Progress: "
while [ $(ls -1 "$TEMP_DIR"/*.ready 2>/dev/null | wc -l) -lt ${#FILES[@]} ]; do
    echo -ne "\r[PACKER] Progress: $(ls -1 "$TEMP_DIR"/*.ready 2>/dev/null | wc -l) / ${#FILES[@]} "
    sleep 0.5
done
echo ""

echo -e "[PACKER] Все потоки завершены. Сборка финального файла..."

# --- 4. Сборка и финализация ---
for i in "${!FILES[@]}"; do
    cat "$TEMP_DIR/$i.chunk" >> "$NEW_UNPACKER"
done

mv "$NEW_UNPACKER" "_unpacker.sh"
chmod +x "_unpacker.sh"
rm -rf "$TEMP_DIR"

# --- 5. Создание ZIP архива ---
ZIP_DATE=$(date +"%d.%m.%Y_%H-%M")
ZIP_NAME="routerFW_LinuxDockerBuilder_v$ZIP_DATE.tar.gz"

echo -e "[PACKER] Создание резервной копии в $ZIP_NAME..."
tar -czf "$ZIP_NAME" "_unpacker.sh"

echo -e "${C_OK}========================================${C_RST}"
echo -e "  Файл обновлен: _unpacker.sh"
echo -e "  Архив создан:  $ZIP_NAME"
echo -e "  ГОТОВО (v2.1 SH MT)"
echo -e "${C_OK}========================================${C_RST}"