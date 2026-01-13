#!/bin/bash
# file: system/src_builder.sh
set -e

# 1. Исправление прав (выполняется под root)
echo '[INIT] Checking volume permissions...'
chown -R build:build /home/build/openwrt /ccache 2>/dev/null || true

# 2. Основная логика от пользователя build
sudo -E -u build bash << 'EOF'
set -e
export HOME=/home/build
PROFILE_ID=$(basename "$CONF_FILE" .conf)

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 0. Подготовка конфига
[ -f "/profiles/$CONF_FILE" ] || { echo "FATAL: Profile /profiles/$CONF_FILE not found!"; exit 1; }
cat "/profiles/$CONF_FILE" | sed '1s/^\xEF\xBB\xBF//' | tr -d '\r' > /tmp/clean_config.env
source /tmp/clean_config.env

export SRC_REPO SRC_BRANCH SRC_TARGET SRC_SUBTARGET SRC_DEVICE PROFILE_NAME SRC_PACKAGES

echo "=================================================="
echo "   OpenWrt SOURCE Builder for $PROFILE_NAME"
echo "=================================================="

START_TIME=$(date +%s)
TIMESTAMP=$(TZ='UTC-3' date +%d%m%y-%H%M%S)

# 1. GIT
if [ ! -d ".git" ]; then
    git config --global init.defaultBranch master
    git config --global http.postBuffer 524288000
    git config --global http.version HTTP/1.1
    git init
    git remote add origin "$SRC_REPO"
fi

echo "[GIT] Fetching and Resetting..."
git fetch origin "$SRC_BRANCH"
git config --global advice.detachedHead false
git checkout -f "FETCH_HEAD"
git reset --hard "FETCH_HEAD"

# Зеркалирование фидов
if [ -f feeds.conf.default ] && ! grep -q "immortalwrt" feeds.conf.default; then
    sed -i 's|https://git.openwrt.org/feed/|https://github.com/openwrt/|g' feeds.conf.default
    sed -i 's|https://git.openwrt.org/project/|https://github.com/openwrt/|g' feeds.conf.default
fi

echo "[FEEDS] Updating..."
./scripts/feeds update -a && ./scripts/feeds install -a

# === ХУКИ И ПРОВЕРКА СОСТОЯНИЯ (ROLLBACK) ===
TARGET_MK="include/kernel-defaults.mk"
BACKUP_MK="include/kernel-defaults.mk.bak"
VERMAGIC_MARKER=".last_vermagic"

if [ -f "/overlay_files/hooks.sh" ]; then
    echo "[HOOKS] Executing hooks.sh..."
    tr -d '\r' < "/overlay_files/hooks.sh" > /tmp/hooks.sh
    chmod +x /tmp/hooks.sh
    /bin/bash /tmp/hooks.sh || exit 1
else
    # ЛОГИКА ОТКАТА (Rollback)
    NEEDS_ROLLBACK=false
    if [ -f "$TARGET_MK" ] && grep -Eq 'echo [0-9a-f]{32}' "$TARGET_MK"; then NEEDS_ROLLBACK=true; fi
    if [ -f "$VERMAGIC_MARKER" ] || [ -f "$BACKUP_MK" ]; then NEEDS_ROLLBACK=true; fi

    if [ "$NEEDS_ROLLBACK" = "true" ]; then
        echo -e "${YELLOW}[HOOKS] Dirty state detected. Rolling back...${NC}"
        [ -f "$BACKUP_MK" ] && cp -f "$BACKUP_MK" "$TARGET_MK" && rm -f "$BACKUP_MK"
        rm -f "$VERMAGIC_MARKER"
        make target/linux/clean > /dev/null 2>&1 || true
        rm -rf tmp/.packageinfo tmp/.targetinfo 2>/dev/null
        find build_dir/target-* -maxdepth 1 -type d -name "linux-*" -exec rm -rf {} + 2>/dev/null || true
        [ -d "/ccache" ] && rm -rf /ccache/*
        echo -e "${GREEN}[HOOKS] Rollback complete.${NC}"
    fi
fi

# 3. КОНФИГУРАЦИЯ (.config)
rm -f .config
if [ -f "/output/manual_config" ]; then
    echo "[CONFIG] Using manual_config..."
    cp "/output/manual_config" .config
else
    echo "CONFIG_CCACHE=y" >> .config
    echo "CONFIG_TARGET_${SRC_TARGET}=y" >> .config
    echo "CONFIG_TARGET_${SRC_TARGET}_${SRC_SUBTARGET}=y" >> .config
    echo "CONFIG_TARGET_${SRC_TARGET}_${SRC_SUBTARGET}_DEVICE_${TARGET_PROFILE}=y" >> .config
    for pkg in $SRC_PACKAGES; do
        [[ "$pkg" == -* ]] && echo "# CONFIG_PACKAGE_${pkg#-} is not set" >> .config || echo "CONFIG_PACKAGE_$pkg=y" >> .config
    done
    [ -n "$ROOTFS_SIZE" ] && echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE" >> .config
    [ -n "$KERNEL_SIZE" ] && echo "CONFIG_TARGET_KERNEL_PARTSIZE=$KERNEL_SIZE" >> .config
    for opt in $SRC_EXTRA_CONFIG; do echo "$opt" >> .config; done
fi

make defconfig

# 4. OVERLAY И ПАКЕТЫ
[ -d "/input_packages" ] && [ "$(ls -A /input_packages)" ] && cp -rf /input_packages/* package/
if [ -d "/overlay_files" ] && [ "$(ls -A /overlay_files)" ]; then
    mkdir -p files && cp -r /overlay_files/* files/ && rm -f files/hooks.sh
fi

# 5. СБОРКА
echo "[DOWNLOAD] Starting..."
make download || make download V=s

SYS_CORES=$(nproc)
BUILD_JOBS=$SYS_CORES
[[ "$SRC_CORES" =~ ^[0-9]+$ ]] && BUILD_JOBS=$SRC_CORES
[[ "$SRC_CORES" == "safe" ]] && BUILD_JOBS=$((SYS_CORES - 1))

echo "[BUILD] Using -j$BUILD_JOBS"
make -j$BUILD_JOBS || make -j1 V=s

# 6. СОХРАНЕНИЕ
TARGET_DIR="/output/$TIMESTAMP"
mkdir -p "$TARGET_DIR"
find bin/targets/$SRC_TARGET -type f -not -path "*/packages/*" -exec cp {} "$TARGET_DIR/" \;
cp .config "$TARGET_DIR/build.config"

ELAPSED=$(($(date +%s) - START_TIME))
echo -e "\n=== Build $PROFILE_NAME completed in ${ELAPSED}s. ===\n"
EOF
