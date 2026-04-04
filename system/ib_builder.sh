#!/bin/bash
# file: system/ib_builder.sh v1.9
set -e

# Цвета для логов
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[FATAL] $1${NC}"; exit 1; }

# 1. Проверка профиля
[ -f "/profiles/$CONF_FILE" ] || error "Profile /profiles/$CONF_FILE not found!"

# === 0. ПОВЫШЕНИЕ СТАБИЛЬНОСТИ СЕТИ ===
echo -e "tries = 5\ntimeout = 20\nretry_connrefused = on\nwaitretry = 2" > ~/.wgetrc

# === 1. ПОДГОТОВКА КОНФИГУРАЦИИ ===
log "Normalizing config..."
cat "/profiles/$CONF_FILE" | sed '1s/^\xEF\xBB\xBF//' | tr -d '\r' > /tmp/clean_config.env
source /tmp/clean_config.env

# Обратная совместимость: поддержка старых имён переменных в профилях
PKGS="${IMAGE_PKGS:-$PKGS}"
EXTRA_IMAGE_NAME="${IMAGE_EXTRA_NAME:-$EXTRA_IMAGE_NAME}"

[ -z "$IMAGEBUILDER_URL" ] && error "IMAGEBUILDER_URL is empty! Config parse failed."

# /output теперь монтирует весь firmware_output; путь записи — imagebuilder/$p_id
REL_PATH="${HOST_OUTPUT_DIR#*firmware_output/}"
OUTPUT_BASE="/output/$REL_PATH"

START_TIME=$(date +%s)
TIMESTAMP=$(TZ='UTC-3' date +%d%m%y-%H%M%S)

# --- 2. СКАЧИВАНИЕ SDK (БЕЗ ОЖИДАНИЯ, С ПЕРЕЗАПУСКОМ) ---
if [[ "$IMAGEBUILDER_URL" =~ ^https?:// ]]; then
    # Сетевой URL: очищаем от ? (например ?download=), качаем в кэш
    CLEAN_URL=$(echo "$IMAGEBUILDER_URL" | sed 's/[?&].*//')
    ARCHIVE_NAME=$(basename "$CLEAN_URL")
    CACHE_FILE="/cache/$ARCHIVE_NAME"
    TEMP_CACHE_FILE="/cache/$ARCHIVE_NAME.tmp"
    if [ ! -f "$CACHE_FILE" ]; then
        log "SDK not found. Preparing fresh download..."
        [ -f "$TEMP_CACHE_FILE" ] && { log "Removing stale .tmp file..."; rm -f "$TEMP_CACHE_FILE"; }
        log "Downloading $ARCHIVE_NAME..."
        wget --progress=dot:giga --tries=5 --timeout=20 --retry-connrefused -O "$TEMP_CACHE_FILE" "$IMAGEBUILDER_URL"
        mv "$TEMP_CACHE_FILE" "$CACHE_FILE"
    else
        log "Using cached $ARCHIVE_NAME"
    fi
else
    # Локальный путь: firmware_output/... в контейнере = /output/...
    LOCAL_PATH_NORM=$(echo "$IMAGEBUILDER_URL" | tr '\\' '/')
    LOCAL_PATH="/output/${LOCAL_PATH_NORM#firmware_output/}"
    ARCHIVE_NAME=$(basename "$LOCAL_PATH")
    CACHE_FILE="/cache/$ARCHIVE_NAME"
    [ -f "$LOCAL_PATH" ] || error "Local imagebuilder file not found: $LOCAL_PATH"
    if [ -f "$CACHE_FILE" ]; then
        log "Using cached $ARCHIVE_NAME"
    else
        log "Using local imagebuilder: $LOCAL_PATH"
        cp "$LOCAL_PATH" "$CACHE_FILE"
    fi
fi

# Распаковка
log "Extracting SDK..."
# Проверяем расширение по имени файла, а не по ссылке
if [[ "$ARCHIVE_NAME" == *".zst" ]]; then
    # Убираем подавление ошибок! Если архив битый - надо падать.
    tar -I zstd -xf "$CACHE_FILE" --strip-components=1 || error "Failed to extract ZST archive"
else
    tar -xJf "$CACHE_FILE" --strip-components=1 || error "Failed to extract XZ archive"
fi

# Проверка, что распаковка прошла успешно (поддержка opkg и apk)
[ -f "repositories.conf" ] || [ -f "repositories" ] || [ -f "Makefile" ] || error "Extraction failed: Build root not found!"

# --- 3. ПОДГОТОВКА ОКРУЖЕНИЯ ---
if [ -f /openssl.cnf ]; then
    log "Applying OpenSSL Fix..."
    mkdir -p /builder/shared-workdir/build/staging_dir/host/etc/ssl
    cp /openssl.cnf /builder/shared-workdir/build/staging_dir/host/etc/ssl/openssl.cnf 2>/dev/null || true
fi

if [ -d /input_packages ]; then
    log "Processing input packages..."
    # КРИТИЧНО: Гарантируем наличие папки перед копированием
    mkdir -p packages/
    # Удаляем stale локальные пакеты от прошлых запусков
    rm -f packages/*.apk packages/*.ipk 2>/dev/null || true

    # Копируем IPK (старый формат)
    cp /input_packages/*.ipk packages/ 2>/dev/null || true

    # Обработка APK (новый формат)
    if ls /input_packages/*.apk 1>/dev/null 2>&1; then
        apk_count=$(ls /input_packages/*.apk 2>/dev/null | wc -l)
        log "Found $apk_count APK file(s). Copying to packages/..."
        cp /input_packages/*.apk packages/ 2>/dev/null || true

        # Удаляем старый индекс, чтобы исключить stale-состояние
        rm -f packages/packages.adb

        # Валидация APK (проверяем уже скопированные файлы)
        valid_apk=0
        for apk_file in packages/*.apk; do
            [ -e "$apk_file" ] || continue
            apk_name=$(basename "$apk_file")

            if [ ! -s "$apk_file" ]; then
                warn "Empty APK file: $apk_name (removed from build)"
                rm -f "$apk_file"
            else
                log "  + $apk_name ($(du -h "$apk_file" | cut -f1))"
                valid_apk=$((valid_apk + 1))
            fi
        done

        # Проверяем, что APK читаются host-apk (быстрая диагностика "битого"/несовместимого файла)
        if [ "$valid_apk" -gt 0 ]; then
            APK_BIN=""
            [ -x "./staging_dir/host/bin/apk" ] && APK_BIN="./staging_dir/host/bin/apk"
            if [ -z "$APK_BIN" ] && command -v apk >/dev/null 2>&1; then
                APK_BIN="$(command -v apk)"
            fi

            if [ -n "$APK_BIN" ]; then
                APK_BIN="$(realpath "$APK_BIN" 2>/dev/null || echo "$APK_BIN")"
                log "Validating APK metadata via $APK_BIN..."
                for apk_file in packages/*.apk; do
                    [ -e "$apk_file" ] || continue
                    if ! "$APK_BIN" adbdump "$apk_file" >/dev/null 2>&1; then
                        error "APK metadata parse failed: $(basename "$apk_file"). Incompatible/corrupted APK."
                    fi
                done
            else
                warn "apk binary not found before make image; metadata validation skipped."
            fi
        else
            warn "No valid APK files left after validation."
        fi
    fi
fi
export SOURCE_DATE_EPOCH=$(date +%s)

# === ИЗМЕНЕНИЕ РАЗМЕРА РАЗДЕЛОВ ===
if [ -n "$ROOTFS_SIZE" ]; then
    log "Setting RootFS size to $ROOTFS_SIZE MB..."
    touch .config
    sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE" >> .config
fi

if [ -n "$KERNEL_SIZE" ]; then
    log "Setting Kernel size to $KERNEL_SIZE MB..."
    touch .config
    sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d' .config
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=$KERNEL_SIZE" >> .config
fi

# --- 4. ЗАГРУЗКА КЛЮЧЕЙ И РЕПОЗИТОРИЕВ ---
if [ -n "$CUSTOM_KEYS" ]; then
    log "Downloading custom keys..."
    for key_url in $CUSTOM_KEYS; do
        wget -q --tries=5 --timeout=15 --retry-connrefused "$key_url" -P keys/ || warn "Failed to download key: $key_url"
        key_filename=$(basename "$key_url")
        key_id=${key_filename%.*}
        if [ -f "keys/$key_filename" ] && [ "$key_filename" != "$key_id" ]; then cp "keys/$key_filename" "keys/$key_id"; fi
    done
fi

if [ -n "$CUSTOM_REPOS" ]; then
    log "Adding custom repositories..."
    if [ -f "repositories.conf" ]; then
        # Legacy OPKG (OpenWrt 24.x и старее)
        sed -i '/fantastic_/d' repositories.conf 2>/dev/null || true
        echo "$CUSTOM_REPOS" | sed 's# src/gz#\nsrc/gz#g' | while read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            echo "${line%/}" >> repositories.conf
        done
    elif [ -f "repositories" ]; then
        # New APK (OpenWrt 25.x и новее)
        echo "$CUSTOM_REPOS" | sed 's# src/gz#\nsrc/gz#g' | while read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Оптимизация: чистый Bash вместо grep/awk
            if [[ "$line" == src/* ]]; then
                read -r _ _ url _ <<< "$line"
                [ -n "$url" ] && echo "${url%/}" >> repositories
            else
                echo "${line%/}" >> repositories
            fi
        done
    fi
fi

# === ПОДГОТОВКА OVERLAY ===
log "Preparing custom files..."
mkdir -p /tmp/clean_overlay
[ -d "/overlay_files" ] && cp -a /overlay_files/. /tmp/clean_overlay/ 2>/dev/null || true
rm -f "/tmp/clean_overlay/hooks.sh" "/tmp/clean_overlay/README.md"

# --- 6. ЗАПУСК СБОРКИ (С ПОВТОРОМ) ---
log "Starting make image for $TARGET_PROFILE..."
# Жестко отключаем signature-check в .config (для локальных неподписанных/чужих APK)
touch .config
sed -i '/^CONFIG_SIGNATURE_CHECK=/d;/^# CONFIG_SIGNATURE_CHECK is not set/d' .config
echo '# CONFIG_SIGNATURE_CHECK is not set' >> .config

# Используем очищенный overlay (/tmp/clean_overlay), а не исходный
# CONFIG_SIGNATURE_CHECK="" отключает проверку подписей локальных (и сетевых) APK
MAKE_ARGS=(
    "PROFILE=$TARGET_PROFILE"
    "FILES=/tmp/clean_overlay"
    "PACKAGES=$PKGS"
    "CONFIG_SIGNATURE_CHECK="
)
[ -n "$EXTRA_IMAGE_NAME" ] && MAKE_ARGS+=("EXTRA_IMAGE_NAME=$EXTRA_IMAGE_NAME")
[ -n "$DISABLED_SERVICES" ] && MAKE_ARGS+=("DISABLED_SERVICES=$DISABLED_SERVICES")

SUCCESS=0
set -o pipefail # Гарантирует, что ошибка от make не "проглотится" командой sed
for i in {1..2}; do
    log "Attempt $i of 2..."
    if make image "${MAKE_ARGS[@]}" 2>&1 | sed -u "s|WARNING: opening .*/packages\.adb: No such file or directory|$(printf '%b' "$GREEN")[INFO]$(printf '%b' "$NC") Generating local packages.adb index...|"; then
        SUCCESS=1
        break
    else 
        warn "Build failed! Retrying in 5s..."
        sleep 5
    fi
done
set +o pipefail

[ $SUCCESS -eq 0 ] && error "Build failed after 2 attempts."

# --- 7. СОХРАНЕНИЕ РЕЗУЛЬТАТОВ ---
log "Saving artifacts..."
TARGET_DIR="$OUTPUT_BASE/$TIMESTAMP"
mkdir -p "$TARGET_DIR"
find bin/targets -type f -not -path "*/packages/*" -exec cp {} "$TARGET_DIR/" \;

# Метаданные ядра из profiles.json (версия и vermagic)
META_FILE="$TARGET_DIR/profiles.json"
if [ -f "$META_FILE" ]; then
    meta_line=$(tr -d '\n' < "$META_FILE")
    kernel_ver=$(echo "$meta_line" | sed -n 's/.*"linux_kernel":[^}]*"version":"\([^"]*\)".*/\1/p')
    kernel_vm=$(echo "$meta_line" | sed -n 's/.*"linux_kernel":[^}]*"vermagic":"\([^"]*\)".*/\1/p')
    if [ -n "$kernel_ver" ] || [ -n "$kernel_vm" ]; then
        echo ""
        printf '%b kernel %s  vermagic %s\n' "${CYAN}[LINUX KERNEL]${NC}" "${kernel_ver:-?}" "${kernel_vm:-?}"
    fi
fi

# Список: папка (метка времени подсвечена) + имена файлов с размерами
base_win="${REL_PATH//\//\\}"
echo ""
printf '%b  firmware_output\\%s\\%b\\\n' "${CYAN}[FIRMWARE FOLDER]${NC}" "${base_win}" "${CYAN}${TIMESTAMP}${NC}"
printf '%b\n' "${CYAN}[FILES]${NC}"
for f in "$TARGET_DIR"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    bytes=$(stat -c%s "$f" 2>/dev/null); bytes=${bytes:-0}
    mb=$(awk "BEGIN {printf \"%.1f\", $bytes/1048576}")
    if [ "$bytes" -ge 31457280 ]; then col="$RED"      # >= 30 MB
    elif [ "$bytes" -ge 10485760 ]; then col="$YELLOW" # >= 10 MB
    else col="$GREEN"; fi
    printf '%s  %b\n' "$name" "${col}[${mb} MB]${NC}"
done

ELAPSED=$(($(date +%s) - START_TIME))
echo -e "\n============================================================"
echo -e "=== Build completed in ${ELAPSED}s."
echo -e "=== Artifacts: firmware_output/$REL_PATH/$TIMESTAMP"
echo -e "============================================================\n"
# checksum:MD5=13d9c0e22299b3f3ba2ff8980859c985