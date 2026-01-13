#!/bin/bash
# file: system/ib_builder.sh
set -e

# Цвета для логов
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

[ -z "$IMAGEBUILDER_URL" ] && error "IMAGEBUILDER_URL is empty! Config parse failed."

START_TIME=$(date +%s)
TIMESTAMP=$(TZ='UTC-3' date +%d%m%y-%H%M%S)

# --- 2. СКАЧИВАНИЕ SDK (БЕЗ ОЖИДАНИЯ, С ПЕРЕЗАПУСКОМ) ---
ARCHIVE_NAME=$(basename "$IMAGEBUILDER_URL")
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

# Распаковка
log "Extracting SDK..."
if echo "$IMAGEBUILDER_URL" | grep -q '.zst$'; then
    tar -I zstd -xf "$CACHE_FILE" --strip-components=1 2>/dev/null || true
else
    tar -xJf "$CACHE_FILE" --strip-components=1 2>/dev/null || true
fi

# --- 3. ПОДГОТОВКА ОКРУЖЕНИЯ ---
if [ -f /openssl.cnf ]; then
    log "Applying OpenSSL Fix..."
    mkdir -p /builder/shared-workdir/build/staging_dir/host/etc/ssl
    cp /openssl.cnf /builder/shared-workdir/build/staging_dir/host/etc/ssl/openssl.cnf 2>/dev/null || true
fi

[ -d /input_packages ] && cp /input_packages/*.ipk packages/ 2>/dev/null || true
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
    sed -i '/fantastic_/d' repositories.conf
    echo -e "$(echo "$CUSTOM_REPOS" | sed 's# src/gz#\nsrc/gz#g')" >> repositories.conf
fi

# === ПОДГОТОВКА OVERLAY ===
log "Preparing custom files..."
mkdir -p /tmp/clean_overlay
[ -d "/overlay_files" ] && cp -a /overlay_files/. /tmp/clean_overlay/ 2>/dev/null || true
rm -f "/tmp/clean_overlay/hooks.sh" "/tmp/clean_overlay/README.md"

# --- 6. ЗАПУСК СБОРКИ (С ПОВТОРОМ) ---
log "Starting make image for $TARGET_PROFILE..."
MAKE_ARGS="PROFILE=\"$TARGET_PROFILE\" FILES=\"/overlay_files\" PACKAGES=\"$PKGS\""
[ -n "$EXTRA_IMAGE_NAME" ] && MAKE_ARGS="$MAKE_ARGS EXTRA_IMAGE_NAME=\"$EXTRA_IMAGE_NAME\""
[ -n "$DISABLED_SERVICES" ] && MAKE_ARGS="$MAKE_ARGS DISABLED_SERVICES=\"$DISABLED_SERVICES\""

SUCCESS=0
for i in {1..3}; do
    log "Attempt $i of 3..."
    if eval make image $MAKE_ARGS; then SUCCESS=1; break;
    else warn "Build failed! Retrying in 5s..."; sleep 5; fi
done

[ $SUCCESS -eq 0 ] && error "Build failed after 3 attempts."

# --- 7. СОХРАНЕНИЕ РЕЗУЛЬТАТОВ ---
log "Saving artifacts..."
TARGET_DIR="/output/$TIMESTAMP"
mkdir -p "$TARGET_DIR"
find bin/targets -type f -not -path "*/packages/*" -exec cp {} "$TARGET_DIR/" \;

ELAPSED=$(($(date +%s) - START_TIME))
echo -e "\n============================================================"
echo -e "=== Build completed in ${ELAPSED}s."
echo -e "=== Artifacts: firmware_output/imagebuilder/$PROFILE_NAME/$TIMESTAMP"
echo -e "============================================================\n"
