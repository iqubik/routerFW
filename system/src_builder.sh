#!/bin/bash
# file: system/src_builder.sh v1.5
set -e

# 1. Исправление прав (выполняется под root)
echo '[INIT] Checking volume permissions...'
#  OPTIMIZED PERMISSION FIX
if [ ! -d "/home/build/openwrt/.git" ] || [ "$(stat -c %U /ccache)" != "build" ]; then
    echo '[INIT] Setting volume permissions (this might take a while on the first run)...'
    chown -R build:build /home/build/openwrt /ccache 2>/dev/null || true
else
    echo '[INIT] Volume permissions appear correct. Skipping slow chown.'
fi

# 2. Основная логика от пользователя build
sudo -E -u build bash << 'EOF'
set -e
export HOME=/home/build
PROFILE_ID=$(basename "$CONF_FILE" .conf)

# FIX: Разрешаем Git работать с папкой, даже если owner UID отличается (актуально для Docker)
git config --global --add safe.directory '*'

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

#  BUILD CACHING CONFIGURATION
echo "[CACHE] Applying build cache optimizations (Rust wrapper, 20G size limit)..."
export RUSTC_WRAPPER="ccache"
export CCACHE_MAXSIZE="20G"
export CCACHE_COMPRESS="true"

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

# Зеркалирование фидов (должно выполняться всегда)
if [ -f feeds.conf.default ] && ! grep -q "immortalwrt" feeds.conf.default; then
    sed -i 's|https://git.openwrt.org/feed/|https://github.com/openwrt/|g' feeds.conf.default
    sed -i 's|https://git.openwrt.org/project/|https://github.com/openwrt/|g' feeds.conf.default
fi

#  FEEDS UPDATE OPTIMIZATION
CURRENT_COMMIT=$(git rev-parse FETCH_HEAD)
LAST_COMMIT_FILE="/ccache/.last_build_commit" # Используем /ccache, так как это постоянное хранилище

# Сравниваем текущий коммит с последним сохраненным.
if [ -f "$LAST_COMMIT_FILE" ] && [ "$CURRENT_COMMIT" == "$(cat $LAST_COMMIT_FILE)" ]; then
    echo "[FEEDS] Main repo commit unchanged. Skipping slow update/install."
else
    echo "[FEEDS] Main repo commit changed or first run. Updating feeds..."
    
    # Основная команда обновления и установки
    ./scripts/feeds update -a && ./scripts/feeds install -a

    # Сохраняем новый хэш после успешного обновления
    echo "$CURRENT_COMMIT" > "$LAST_COMMIT_FILE"
    echo "[FEEDS] Feeds updated and commit hash saved."
fi

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
    # ЛОГИКА ОТКАТА (Rollback) с детальной диагностикой
    echo -e "${CYAN}[HOOKS] hooks.sh not found. Validating system state...${NC}"
    echo ""
    echo "[DEBUG] ========== STATE CHECK BEGIN =========="
    echo "[DEBUG] TARGET_MK = $TARGET_MK"
    echo "[DEBUG] BACKUP_MK = $BACKUP_MK"
    echo "[DEBUG] VERMAGIC_MARKER = $VERMAGIC_MARKER"
    echo ""

    NEEDS_ROLLBACK=false
    IS_PATCHED=false

    echo "[DEBUG] Check 1: Is Makefile patched?"
    if [ -f "$TARGET_MK" ]; then
        if grep -Eq 'echo [0-9a-f]{32}' "$TARGET_MK" 2>/dev/null; then
            echo -e "[DEBUG]   - Status: ${RED}PATCHED${NC} (Hardcoded hash found)"
            IS_PATCHED=true
            NEEDS_ROLLBACK=true
        else
            if grep -E 'MKHASH|mkhash|md5sum' "$TARGET_MK" >/dev/null 2>&1; then
                echo -e "[DEBUG]   - Status: ${GREEN}CLEAN${NC} (Standard logic found)"
            else
                echo -e "[DEBUG]   - Status: ${YELLOW}UNKNOWN${NC} (Inconclusive syntax)"
                if [ -f "$BACKUP_MK" ]; then NEEDS_ROLLBACK=true; fi
            fi
        fi
    else
        echo "[DEBUG]   - File exists: NO"
    fi

    echo "[DEBUG] Check 2: Vermagic marker?"
    if [ -f "$VERMAGIC_MARKER" ]; then
        MARKER_CONTENT=$(cat "$VERMAGIC_MARKER")
        echo -e "[DEBUG]   - Marker exists: ${RED}YES${NC} (content: $MARKER_CONTENT)"
        NEEDS_ROLLBACK=true
    else
        echo -e "[DEBUG]   - Marker exists: ${GREEN}NO${NC}"
    fi

    echo "[DEBUG] Check 3: Backup exists?"
    if [ -f "$BACKUP_MK" ]; then
        echo -e "[DEBUG]   - Backup: ${RED}YES${NC}"
        NEEDS_ROLLBACK=true
    else
        echo -e "[DEBUG]   - Backup exists: ${GREEN}NO${NC}"
    fi

    echo "[DEBUG] NEEDS_ROLLBACK = $NEEDS_ROLLBACK"
    echo "[DEBUG] ========== STATE CHECK END =========="
    echo ""

    if [ "$NEEDS_ROLLBACK" = "false" ]; then
        echo -e "${GREEN}[HOOKS] System is in clean state.${NC}"
    else
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
    
    # FIX: Priority to SRC_EXTRA_CONFIG for Device Selection
    if echo "$SRC_EXTRA_CONFIG" | grep -q "CONFIG_TARGET_.*_DEVICE_"; then
        echo "[CONFIG] Device selection delegated to SRC_EXTRA_CONFIG."
    else
        # Fallback to standard logic (ensure underscores)
        CLEAN_PROFILE=$(echo "$TARGET_PROFILE" | tr '-' '_')
        echo "CONFIG_TARGET_${SRC_TARGET}_${SRC_SUBTARGET}_DEVICE_${CLEAN_PROFILE}=y" >> .config
    fi
    for pkg in $SRC_PACKAGES; do
        [[ "$pkg" == -* ]] && echo "# CONFIG_PACKAGE_${pkg#-} is not set" >> .config || echo "CONFIG_PACKAGE_$pkg=y" >> .config
    done
    [ -n "$ROOTFS_SIZE" ] && echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE" >> .config
    [ -n "$KERNEL_SIZE" ] && echo "CONFIG_TARGET_KERNEL_PARTSIZE=$KERNEL_SIZE" >> .config
    # Исправление: выводим блок целиком, сохраняя пробелы внутри строк
    if [ -n "$SRC_EXTRA_CONFIG" ]; then
        printf "%b\n" "$SRC_EXTRA_CONFIG" | tr -d '\r' | while IFS= read -r line; do
            [ -n "$line" ] && echo "$line" >> .config
        done
    fi
fi

make defconfig

# 4. OVERLAY И ПАКЕТЫ
[ -d "/input_packages" ] && [ "$(ls -A /input_packages)" ] && cp -rf /input_packages/* package/
if [ -d "/overlay_files" ] && [ -n "$(ls -A /overlay_files)" ]; then
    echo "[SYNC] Syncing overlay files..."
    mkdir -p files/
    rsync -a --delete /overlay_files/ files/
    # По-прежнему удаляем hooks.sh, т.к. он не должен попасть в прошивку
    rm -f files/hooks.sh
fi

# 5. СБОРКА
echo "[DOWNLOAD] Starting..."
make download || make download V=s

SYS_CORES=$(nproc)
BUILD_JOBS=$SYS_CORES
[[ "$SRC_CORES" =~ ^[0-9]+$ ]] && BUILD_JOBS=$SRC_CORES
[[ "$SRC_CORES" == "safe" ]] && BUILD_JOBS=$((SYS_CORES - 1))

echo "[BUILD] Attempt 1: Building with -j$BUILD_JOBS..."
if ! make -j$BUILD_JOBS; then
    echo -e "\n${RED}[BUILD ERROR] Parallel build failed! Starting Attempt 2: -j1 V=s (Debug mode)...${NC}\n"
    make -j1 V=s
fi

# 6. СОХРАНЕНИЕ
TARGET_DIR="/output/$TIMESTAMP"
mkdir -p "$TARGET_DIR"
find bin/targets/$SRC_TARGET -type f -not -path "*/packages/*" -exec mv {} "$TARGET_DIR/" \;
cp .config "$TARGET_DIR/build.config"

ELAPSED=$(($(date +%s) - START_TIME))
echo -e "\n=== Build $PROFILE_NAME completed in ${ELAPSED}s. ===\n"
EOF
