#!/bin/bash
# ======================================================================================
#  Универсальный скрипт-хук для Source Builder v1.6 // Universal hook script for Source Builder
# ======================================================================================
#
#  ИЗМЕНЕНИЕ: Комментарии внутри скрипта были улучшены для максимальной ясности.
#  CHANGE: In-script comments improved for maximum clarity.
#
#  ОПИСАНИЕ: // DESCRIPTION:
#  Этот скрипт является мощным инструментом для глубокой настройки процесса сборки.
#  This script is a powerful tool for deep customization of the build process.
#  Он выполняется внутри Docker-контейнера и позволяет вносить изменения "на лету"
#  непосредственно перед основной фазой компиляции.
#  It runs inside Docker and allows "on-the-fly" changes before the main compilation.
#
#  КОНТЕКСТ ВЫПОЛНЕНИЯ (src_builder.sh): // EXECUTION CONTEXT:
#  Скрипт запускается в строго определенный момент: // Script runs at a specific stage:
#    1. git clone/fetch: Исходный код OpenWrt скачан и обновлен. // OpenWrt source downloaded.
#    2. ./scripts/feeds update/install: Стандартные фиды установлены. // Standard feeds installed.
#    3. >> ЗАПУСК hooks.sh << : Модификация исходников или фидов. // >> START hooks.sh << : Source modification.
#    4. make defconfig: Генерируется финальный .config. // Final .config generation.
#    5. make: Начинается основная компиляция. // Main compilation starts.
#
#  КЛЮЧЕВЫЕ ВОЗМОЖНОСТИ ШАБЛОНА: // KEY TEMPLATE FEATURES:
#    - Модификация файлов: Правка DTS, Makefile, C-кода. // File modification: DTS, Makefile, C-code.
#    - Скрипты первого запуска: Создание uci-defaults. // First-run scripts: uci-defaults creation.
#    - Управление фидами: Добавление репозиториев. // Feed management: Adding repositories.
#    - Vermagic Hack: Совместимость с официальными kmod. // Vermagic Hack: Official kmod compatibility.
#    - Умная очистка кэша: Сброс при необходимости. // Smart cache cleaning: Reset if needed.
#
# ======================================================================================

# ======================================================================================
#  БЛОК 0: ИНИЦИАЛИЗАЦИЯ И ЛОГИРОВАНИЕ // BLOCK 0: INITIALIZATION & LOGGING
# ======================================================================================
# Настройка переменных для цветного вывода. // Setup variables for color output.
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ВАЖНО: Отключаем интерактивный ввод пароля для Git // IMPORTANT: Disable Git interactive prompts
export GIT_TERMINAL_PROMPT=0

# Вспомогательные функции для вывода сообщений. // Helper functions for logging.
log() { echo -e "${CYAN}[HOOK]${NC} $1"; }
warn() { echo -e "${YELLOW}[HOOK] WARNING: $1${NC}"; }
err()  { echo -e "${RED}[HOOK] ERROR: $1${NC}"; }
log ">>> Running hooks.sh script (Universal v1.5.1)..."

# ======================================================================================
#  БЛОК 1: ДЕМОНСТРАЦИЯ МОДИФИКАЦИИ ФАЙЛОВ // BLOCK 1: FILE MODIFICATION DEMO
# ======================================================================================
# Этот блок показывает, как безопасно изменять файлы. // This block shows how to safely modify files.
# Ключевой аспект - идемпотентность (проверка на дубликаты). // Key aspect: idempotency (check for duplicates).
# ======================================================================================
log "Checking and setting build signature..." # Проверка и установка автографа сборки...
TARGET_FILE=$(find . -maxdepth 1 -name "README*" | head -n 1)
[ -z "$TARGET_FILE" ] && TARGET_FILE="README.md" && touch "$TARGET_FILE"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
SIGNATURE="Build processed by SourceBuilder"

# Проверяем, что подпись отсутствует, и только тогда добавляем. // Check if signature is missing before adding.
if ! grep -Fq "$SIGNATURE" "$TARGET_FILE"; then
    log "Adding signature to $TARGET_FILE..." # Добавляем автограф в файл...
    echo "" >> "$TARGET_FILE"
    echo "--- $SIGNATURE on $TIMESTAMP ---" >> "$TARGET_FILE"
    # Валидация записи для надежности // Record validation for reliability
    if grep -Fq "$SIGNATURE" "$TARGET_FILE"; then
        echo -e "${GREEN}       SUCCESS: README updated.${NC}" # УСПЕХ: README обновлен.
    else
        err "Failed to write signature to file!" # Не удалось записать автограф в файл!
    fi
fi

# ======================================================================================
#  БЛОК 1.1: АВТО-ВКЛЮЧЕНИЕ WI-FI (ЧЕРЕЗ UCI-DEFAULTS) // BLOCK 1.1: AUTO-ENABLE WI-FI
# ======================================================================================
# Назначение: Обеспечить работающий Wi-Fi "из коробки". // Purpose: Ensure Wi-Fi works out-of-the-box.
# Метод: Создание скрипта в /etc/uci-defaults. // Method: Create script in /etc/uci-defaults.
# ======================================================================================
log "Checking Wi-Fi configuration (Auto-enable)..." # Проверка конфигурации Wi-Fi...
# Исключаем платформы (например, x86). // Exclude platforms like x86.
if [[ "$SRC_TARGET" == "x86" ]]; then
    warn "For x86 platform, Wi-Fi auto-enable is skipped." # Для x86 авто-включение Wi-Fi пропущено.
else
    # Путь /files/ соответствует корню / в прошивке. // /files/ path matches root / in firmware.
    UCI_DEFAULTS_DIR="files/etc/uci-defaults"
    SCRIPT_NAME="99-enable-wifi"
    # Создаем директорию, если её нет // Create directory if missing
    mkdir -p "$UCI_DEFAULTS_DIR"
    log "Creating first boot script: $UCI_DEFAULTS_DIR/$SCRIPT_NAME" # Создание сценария первой загрузки...

    # Генерируем скрипт активации. // Generate activation script.
    cat <<EOF > "$UCI_DEFAULTS_DIR/$SCRIPT_NAME"
#!/bin/sh
# Включаем все найденные радио-модули // Enable all found radio modules
for radio in \$(uci show wireless | grep =device | cut -d. -f2); do
    uci set wireless.\$radio.disabled='0'
done
uci commit wireless
/sbin/wifi reload
exit 0
EOF
    # Скрипт в uci-defaults ДОЛЖЕН быть исполняемым. // Script must be executable.
    chmod +x "$UCI_DEFAULTS_DIR/$SCRIPT_NAME"

    if [ -f "$UCI_DEFAULTS_DIR/$SCRIPT_NAME" ]; then
        echo -e "${GREEN}       SUCCESS: Wi-Fi activation script added to image.${NC}" # УСПЕХ: Скрипт добавлен.
    else
        err "Failed to create Wi-Fi activation script!" # Не удалось создать скрипт активации!
    fi
fi

# ======================================================================================
#  БЛОК 1.2: АВТОМАТИЧЕСКИЙ ПАТЧ ДЛЯ 16MB FLASH // BLOCK 1.2: AUTO-PATCH FOR 16MB FLASH
# ======================================================================================
# Назначение: Подготовка для устройств с перепаянной флеш-памятью. // Purpose: Hack for 16MB flash mods.
# Применимо для: ramips (mt7621/7628/7688). // Applicable for: ramips platforms.
# ======================================================================================
# if [[ "$SRC_TARGET" == "ramips" && "$SRC_SUBTARGET" == "mt76x8" ]]; then
#     log ">>> Checking hardware Flash limits (16MB Hack)..." # Проверка аппаратных лимитов Flash памяти...
#     DTS_FILE="target/linux/ramips/dts/mt7628an.dtsi"
#     MK_FILE="target/linux/ramips/image/mt76x8.mk"
#     # --- Модификация Device Tree (DTS) --- // DTS Modification
#     if [ -f "$DTS_FILE" ] && ! grep -q "0xfb0000" "$DTS_FILE"; then
#         log "DTS: Increasing 'firmware' partition size..." # DTS: Увеличиваю размер раздела 'firmware'...
#         [ ! -f "${DTS_FILE}.bak" ] && cp "$DTS_FILE" "${DTS_FILE}.bak"
#         sed -i 's/<0x7b0000>/<0xfb0000>/g' "$DTS_FILE"
#         if grep -q "0xfb0000" "$DTS_FILE"; then 
#             echo -e "${GREEN}       SUCCESS: DTS updated.${NC}" # УСПЕХ: DTS обновлен.
#         else 
#             err "Modification error in $DTS_FILE" # Ошибка модификации...
#         fi
#     fi
#     # --- Модификация лимитов Makefile --- // Makefile limits modification
#     if [ -f "$MK_FILE" ] && ! grep -Eiq "16064k|15872k" "$MK_FILE"; then
#         log "MK: Removing 'Image too big' limit..." # MK: Снятие ограничения 'Image too big'...
#         [ ! -f "${MK_FILE}.bak" ] && cp "$MK_FILE" "${MK_FILE}.bak"
#         sed -i -e 's/7872k/15872k/g' -e 's/8064k/16064k/g' "$MK_FILE"
#         echo -e "${GREEN}       SUCCESS: Build limits updated.${NC}" # УСПЕХ: Лимиты сборщика обновлены.
#     fi
# fi

# ======================================================================================
#  БЛОК 1.3: ИСПРАВЛЕНИЕ СБОРКИ RUST (LLVM CI 404 FIX) // BLOCK 1.3: RUST BUILD FIX
# ======================================================================================
# Назначение: Решение проблемы с ошибкой 404 при скачивании LLVM. // Purpose: Fix 404 error on LLVM download.
# Действие: Принудительное включение локальной сборки LLVM. // Action: Force local LLVM build.
# ======================================================================================
RUST_MK="feeds/packages/lang/rust/Makefile"

if [ -f "$RUST_MK" ]; then
    log ">>> Checking Rust configuration (LLVM CI Fix)..." # Проверка конфигурации Rust...

    # 1. Проверяем, применено ли уже исправление (идемпотентность). // Check if fix is already applied.
    if grep -q "llvm.download-ci-llvm=false" "$RUST_MK"; then
        log "Rust LLVM download is already disabled. Skipping." # Загрузка LLVM уже отключена. Пропуск.
    else
        # 2. Ищем, включена ли загрузка (значение true). // Check if download is enabled (true).
        if grep -q "llvm.download-ci-llvm=true" "$RUST_MK"; then
            log "Patching Rust Makefile to disable CI LLVM download..." # Патчим Makefile, отключаем загрузку...
            
            # Создаем бэкап, если его нет // Create backup if missing
            [ ! -f "${RUST_MK}.bak" ] && cp "$RUST_MK" "${RUST_MK}.bak"

            # Заменяем true на false // Replace true with false
            sed -i 's/llvm.download-ci-llvm=true/llvm.download-ci-llvm=false/g' "$RUST_MK"

            # 3. Валидация изменений // Validation
            if grep -q "llvm.download-ci-llvm=false" "$RUST_MK"; then
                echo -e "${GREEN}       SUCCESS: Makefile modified. LLVM will be built locally.${NC}" # УСПЕХ: Makefile изменен.
                
                # ВАЖНО: Очистка пакета, чтобы сбросить старую конфигурацию // IMPORTANT: Clean package to reset config
                log "Cleaning Rust package to apply changes..." 
                make package/feeds/packages/rust/clean >/dev/null 2>&1
            else
                err "Failed to modify Rust Makefile!" # Не удалось изменить Makefile!
            fi
        else
            warn "Flag 'download-ci-llvm=true' not found in Makefile. Manual check required." # Флаг не найден. Требуется ручная проверка.
        fi
    fi
else
    # Если файла нет, возможно, фиды еще не установлены // If file missing, feeds might not be installed
    warn "Rust Makefile not found at $RUST_MK. Skipping fix." # Файл Rust Makefile не найден. Пропуск.
fi

# ======================================================================================
#  БЛОК 2: SMART FEED MANAGER
# ======================================================================================
# Назначение: Управление внешними репозиториями пакетов. // Purpose: Manage external package feeds.
# Функция add_feed инкапсулирует логику добавления. // add_feed function encapsulates addition logic.
# ======================================================================================
log ">>> Checking and integrating external feeds..." # Проверка и интеграция внешних фидов...
add_feed() {
    local FEED_NAME="$1"
    local FEED_URL="$2"
    local FEED_FILE="feeds.conf.default"

    # 1. Проверка, не добавлен ли фид ранее. // Check if feed exists.
    if grep -qE "^src-git ${FEED_NAME} " "$FEED_FILE" || grep -Fq "$FEED_URL" "$FEED_FILE"; then
        log "Feed '$FEED_NAME' already exists. Skipping." # Фид уже присутствует. Пропуск.
    else
        log "Adding feed: $FEED_NAME -> $FEED_URL" # Добавляем фид...
        echo "src-git ${FEED_NAME} ${FEED_URL}" >> "$FEED_FILE"

        # 2. Обновление и установка пакетов ТОЛЬКО из этого фида. // Update/Install ONLY this feed.
        log "Integrating packages from '$FEED_NAME'..." # Интеграция пакетов...
        if ! ./scripts/feeds update "$FEED_NAME"; then
            warn "First update attempt for '$FEED_NAME' failed. Retrying..." # Первая попытка неудачна. Повтор.
            sleep 3
            ./scripts/feeds update "$FEED_NAME"
        fi

        # 3. Финальная проверка и установка. // Final check and install.
        if ./scripts/feeds install -a -p "$FEED_NAME"; then
            echo -e "${GREEN}       SUCCESS: Packages from '$FEED_NAME' installed.${NC}" # УСПЕХ: Пакеты установлены.
        else
            err "Critical error: Failed to update feed '$FEED_NAME'." # Ошибка: Не удалось обновить фид.
            sed -i "/${FEED_NAME}/d" "$FEED_FILE" # Rollback
        fi
    fi
}

# --- СПИСОК РЕПОЗИТОРИЕВ ДЛЯ ДОБАВЛЕНИЯ --- // REPOSITORY LIST TO ADD
# add_feed "amneziawg" "https://github.com/amnezia-vpn/amneziawg-openwrt.git"

# ======================================================================================
#  БЛОК 3: VERMAGIC HACK И УМНАЯ ОЧИСТКА КЭША // BLOCK 3: VERMAGIC HACK & SMART CACHE CLEAN
# ======================================================================================
# Назначение: Обеспечить совместимость с официальными kmod. // Purpose: Ensure kmod compatibility.
# Решение: Подмена vermagic в процессе сборки. // Solution: Patch vermagic during build.
# ======================================================================================
log ">>> Checking if Vermagic Hack is needed..." # Проверка необходимости Vermagic Hack...
CLEAN_VER=$(echo "$SRC_BRANCH" | sed 's/^v//')
VERMAGIC_MARKER=".last_vermagic"
TARGET_MK="include/kernel-defaults.mk"
BACKUP_MK="include/kernel-defaults.mk.bak"

# 1. Определяем дистрибутив (OpenWrt/ImmortalWrt). // Determine distro type.
if grep -riq "immortalwrt" include/version.mk package/base-files/files/etc/openwrt_release 2>/dev/null; then
    DISTRO_NAME="immortalwrt"
    DOWNLOAD_DOMAIN="downloads.immortalwrt.org"
    log "Detected distro: IMMORTALWRT" # Обнаружен дистрибутив: IMMORTALWRT
else
    DISTRO_NAME="openwrt"
    DOWNLOAD_DOMAIN="downloads.openwrt.org"
    log "Detected distro: OPENWRT" # Обнаружен дистрибутив: OPENWRT
fi

# 2. Пропускаем SNAPSHOT/master сборки. // Skip SNAPSHOT/master builds.
if [[ "$CLEAN_VER" == *"SNAPSHOT"* ]] || [[ "$CLEAN_VER" == *"master"* ]]; then
    warn "SNAPSHOT/Master build. Vermagic Hack is not applied." # Сборка SNAPSHOT. Hack не применяется.
    if [ -f "$BACKUP_MK" ]; then
        log "Restoring original Makefile..." # Восстанавливаем оригинальный Makefile...
        cp -f "$BACKUP_MK" "$TARGET_MK"
    fi
else
    log "Target version: $CLEAN_VER ($SRC_TARGET / $SRC_SUBTARGET)" # Целевая версия...
    MANIFEST_URL="https://${DOWNLOAD_DOMAIN}/releases/${CLEAN_VER}/targets/${SRC_TARGET}/${SRC_SUBTARGET}/${DISTRO_NAME}-${CLEAN_VER}-${SRC_TARGET}-${SRC_SUBTARGET}.manifest"

    # 3. Скачиваем манифест. // Download manifest.
    MANIFEST_DATA=$(curl -s --fail "$MANIFEST_URL")
    if [ -z "$MANIFEST_DATA" ]; then
        warn "Manifest not found ($MANIFEST_URL)." # Манифест не найден.
    else
        # 4. Извлекаем хэш ядра (vermagic). // Extract kernel hash.
        KERNEL_HASH=$(echo "$MANIFEST_DATA" | grep -m 1 '^kernel - ' | grep -oE '[0-9a-f]{32}' | head -n 1)

        if [[ ! "$KERNEL_HASH" =~ ^[0-9a-f]{32}$ ]]; then
            err "Invalid kernel hash from manifest." # Некорректный хэш ядра.
        else
            echo -e "${GREEN}       Official Vermagic Hash: $KERNEL_HASH${NC}" # Официальный хэш...
            OLD_HASH=""
            [ -f "$VERMAGIC_MARKER" ] && OLD_HASH=$(cat "$VERMAGIC_MARKER")

            # 5. УМНАЯ ОЧИСТКА КЭША. // SMART CACHE CLEANING.
            if [ "$OLD_HASH" != "$KERNEL_HASH" ]; then
                warn "Hash changed. Deep cache cleaning..." # Хеш изменился. Глубокая очистка...
                make target/linux/clean > /dev/null 2>&1
                rm -rf tmp/.packageinfo tmp/.targetinfo tmp/.config-target.in
                find build_dir/target-* -maxdepth 1 -type d -name "linux-*" -exec rm -rf {} + 2>/dev/null
                rm -rf staging_dir/target-*/pkginfo/kernel.default.install 2>/dev/null
                if [[ "$CLEAN_VER" == "19.07"* ]]; then rm -rf staging_dir/target-*/root-* 2>/dev/null; fi
                echo "$KERNEL_HASH" > "$VERMAGIC_MARKER"
                log "Caches fully reset." # Кэши полностью сброшены.
            else
                log "Kernel hash unchanged. Cache will be used." # Хеш не изменился. Кэш используется.
            fi

            # 6. Патчинг Makefile // Patching Makefile
            if [ -f "$TARGET_MK" ]; then
                PATCH_STRATEGY=""
                SEARCH_PATTERN=""
                # Определение типа синтаксиса // Detect syntax type
                if grep -Fq '$(MKHASH) md5' "$TARGET_MK"; then
                    PATCH_STRATEGY="modern"; SEARCH_PATTERN='\$(MKHASH) md5'
                elif grep -Fq 'mkhash md5' "$TARGET_MK"; then
                    PATCH_STRATEGY="legacy_mkhash"; SEARCH_PATTERN='mkhash md5'
                elif grep -Fq 'md5sum' "$TARGET_MK" && grep -Fq '.vermagic' "$TARGET_MK"; then
                    PATCH_STRATEGY="legacy_md5sum"; SEARCH_PATTERN='md5sum | cut -d . .'
                fi

                if [ -z "$PATCH_STRATEGY" ] && [ -f "$BACKUP_MK" ]; then
                    cp -f "$BACKUP_MK" "$TARGET_MK"
                    # Re-detect...
                    if grep -Fq '$(MKHASH) md5' "$TARGET_MK"; then PATCH_STRATEGY="modern"; SEARCH_PATTERN='\$(MKHASH) md5'; fi
                fi

                if [ -n "$PATCH_STRATEGY" ]; then
                    if [ ! -f "$BACKUP_MK" ]; then
                        warn "First patch. Cleaning CCACHE..." # Первый патч. Очистка CCACHE.
                        [ -d "/ccache" ] && rm -rf /ccache/* 2>/dev/null
                        cp "$TARGET_MK" "$BACKUP_MK"
                    else
                        cp -f "$BACKUP_MK" "$TARGET_MK"
                    fi
                    log "Applying Vermagic patch ($PATCH_STRATEGY)..." # Применяем патч...
                    if [ "$PATCH_STRATEGY" == "legacy_md5sum" ]; then
                        sed -i "s/md5sum | cut -d ' ' -f1/echo $KERNEL_HASH/g" "$TARGET_MK"
                    else
                        sed -i "s/$SEARCH_PATTERN/echo $KERNEL_HASH/g" "$TARGET_MK"
                    fi
                    if grep -q "$KERNEL_HASH" "$TARGET_MK"; then
                        echo -e "${GREEN}       SUCCESS: Makefile modified.${NC}" # УСПЕХ: Makefile модифицирован.
                    else
                        err "Patching error!"; exit 1
                    fi
                else
                    warn "Could not detect hashing method." # Не удалось определить метод хэширования.
                fi
            else
                err "File $TARGET_MK not found."; exit 1 # Файл не найден.
            fi
        fi
    fi
fi
# ======================================================================================
#  ФИНАЛ // FINAL
# ======================================================================================
log ">>> Script hooks.sh finished." # Сценарий hooks.sh завершен.
exit 0