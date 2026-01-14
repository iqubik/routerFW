#!/bin/bash
# ======================================================================================
#  Универсальный скрипт-хук для Source Builder v1.5.1 // Universal hook script for Source Builder
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
log ">>> Запуск сценария hooks.sh (Universal v1.5.1)..."

# ======================================================================================
#  БЛОК 1: ДЕМОНСТРАЦИЯ МОДИФИКАЦИИ ФАЙЛОВ // BLOCK 1: FILE MODIFICATION DEMO
# ======================================================================================
# Этот блок показывает, как безопасно изменять файлы. // This block shows how to safely modify files.
# Ключевой аспект - идемпотентность (проверка на дубликаты). // Key aspect: idempotency (check for duplicates).
# ======================================================================================
log "Проверка и установка автографа сборки..." # Checking and setting build signature...
TARGET_FILE=$(find . -maxdepth 1 -name "README*" | head -n 1)
[ -z "$TARGET_FILE" ] && TARGET_FILE="README.md" && touch "$TARGET_FILE"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
SIGNATURE="Build processed by SourceBuilder"

# Проверяем, что подпись отсутствует, и только тогда добавляем. // Check if signature is missing before adding.
if ! grep -Fq "$SIGNATURE" "$TARGET_FILE"; then
    log "Добавляем автограф в $TARGET_FILE..." # Adding signature to file...
    echo "" >> "$TARGET_FILE"
    echo "--- $SIGNATURE on $TIMESTAMP ---" >> "$TARGET_FILE"
    # Валидация записи для надежности // Record validation for reliability
    if grep -Fq "$SIGNATURE" "$TARGET_FILE"; then
        echo -e "${GREEN}       УСПЕХ: README обновлен.${NC}" # SUCCESS: README updated.
    else
        err "Не удалось записать автограф в файл!" # Failed to write signature!
    fi
fi

# ======================================================================================
#  БЛОК 1.1: АВТО-ВКЛЮЧЕНИЕ WI-FI (ЧЕРЕЗ UCI-DEFAULTS) // BLOCK 1.1: AUTO-ENABLE WI-FI
# ======================================================================================
# Назначение: Обеспечить работающий Wi-Fi "из коробки". // Purpose: Ensure Wi-Fi works out-of-the-box.
# Метод: Создание скрипта в /etc/uci-defaults. // Method: Create script in /etc/uci-defaults.
# ======================================================================================
log "Проверка конфигурации Wi-Fi (Auto-enable)..." # Checking Wi-Fi config...
# Исключаем платформы (например, x86). // Exclude platforms like x86.
if [[ "$SRC_TARGET" == "x86" ]]; then
    warn "Для платформы x86 авто-включение Wi-Fi пропущено." # Skip Wi-Fi for x86.
else
    # Путь /files/ соответствует корню / в прошивке. // /files/ path matches root / in firmware.
    UCI_DEFAULTS_DIR="files/etc/uci-defaults"
    SCRIPT_NAME="99-enable-wifi"
    # Создаем директорию, если её нет // Create directory if missing
    mkdir -p "$UCI_DEFAULTS_DIR"
    log "Создание сценария первой загрузки: $UCI_DEFAULTS_DIR/$SCRIPT_NAME" # Creating uci-defaults script...

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
        echo -e "${GREEN}       УСПЕХ: Скрипт активации Wi-Fi добавлен в образ.${NC}" # SUCCESS: Wi-Fi script added.
    else
        err "Не удалось создать скрипт активации Wi-Fi!" # Failed to create Wi-Fi script!
    fi
fi

# ======================================================================================
#  БЛОК 1.2: АВТОМАТИЧЕСКИЙ ПАТЧ ДЛЯ 16MB FLASH // BLOCK 1.2: AUTO-PATCH FOR 16MB FLASH
# ======================================================================================
# Назначение: Подготовка для устройств с перепаянной флеш-памятью. // Purpose: Hack for 16MB flash mods.
# Применимо для: ramips (mt7621/7628/7688). // Applicable for: ramips platforms.
# ======================================================================================
# if [[ "$SRC_TARGET" == "ramips" && "$SRC_SUBTARGET" == "mt76x8" ]]; then
#     log ">>> Проверка аппаратных лимитов Flash памяти (16MB Hack)..." # Checking flash limits...
#     DTS_FILE="target/linux/ramips/dts/mt7628an.dtsi"
#     MK_FILE="target/linux/ramips/image/mt76x8.mk"

#     # --- Модификация Device Tree (DTS) --- // DTS Modification
#     if [ -f "$DTS_FILE" ] && ! grep -q "0xfb0000" "$DTS_FILE"; then
#         log "DTS: Увеличиваю размер раздела 'firmware'..." # Increasing firmware partition size...
#         [ ! -f "${DTS_FILE}.bak" ] && cp "$DTS_FILE" "${DTS_FILE}.bak"
#         sed -i 's/<0x7b0000>/<0xfb0000>/g' "$DTS_FILE"
#         if grep -q "0xfb0000" "$DTS_FILE"; then echo -e "${GREEN}       УСПЕХ: DTS обновлен.${NC}"; else err "Ошибка модификации $DTS_FILE"; fi
#     fi

#     # --- Модификация лимитов Makefile --- // Makefile limits modification
#     if [ -f "$MK_FILE" ] && ! grep -Eiq "16064k|15872k" "$MK_FILE"; then
#         log "MK: Снятие ограничения 'Image too big'..." # Removing image size limits...
#         [ ! -f "${MK_FILE}.bak" ] && cp "$MK_FILE" "${MK_FILE}.bak"
#         sed -i -e 's/7872k/15872k/g' -e 's/8064k/16064k/g' "$MK_FILE"
#         echo -e "${GREEN}       УСПЕХ: Лимиты сборщика обновлены.${NC}"
#     fi
# fi

# ======================================================================================
#  БЛОК 2: SMART FEED MANAGER
# ======================================================================================
# Назначение: Управление внешними репозиториями пакетов. // Purpose: Manage external package feeds.
# Функция add_feed инкапсулирует логику добавления. // add_feed function encapsulates addition logic.
# ======================================================================================
log ">>> Проверка и интеграция внешних фидов (Feeds)..." # Checking external feeds...
add_feed() {
    local FEED_NAME="$1"
    local FEED_URL="$2"
    local FEED_FILE="feeds.conf.default"

    # 1. Проверка, не добавлен ли фид ранее. // Check if feed exists.
    if grep -qE "^src-git ${FEED_NAME} " "$FEED_FILE" || grep -Fq "$FEED_URL" "$FEED_FILE"; then
        log "Фид '$FEED_NAME' уже присутствует. Пропуск." # Feed already exists. Skip.
    else
        log "Добавляем фид: $FEED_NAME -> $FEED_URL" # Adding new feed...
        echo "src-git ${FEED_NAME} ${FEED_URL}" >> "$FEED_FILE"

        # 2. Обновление и установка пакетов ТОЛЬКО из этого фида. // Update/Install ONLY this feed.
        log "Интеграция пакетов из '$FEED_NAME'..." # Integrating packages...
        if ! ./scripts/feeds update "$FEED_NAME"; then
            warn "Первая попытка обновления '$FEED_NAME' неудачна. Повтор..." # Retry update...
            sleep 3
            ./scripts/feeds update "$FEED_NAME"
        fi

        # 3. Финальная проверка и установка. // Final check and install.
        if ./scripts/feeds install -a -p "$FEED_NAME"; then
            echo -e "${GREEN}       УСПЕХ: Пакеты из '$FEED_NAME' установлены.${NC}" # SUCCESS: Packages installed.
        else
            err "Критическая ошибка: Не удалось обновить фид '$FEED_NAME'." # Error: Failed to update feed.
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
log ">>> Проверка необходимости Vermagic Hack..." # Checking for Vermagic Hack...
CLEAN_VER=$(echo "$SRC_BRANCH" | sed 's/^v//')
VERMAGIC_MARKER=".last_vermagic"
TARGET_MK="include/kernel-defaults.mk"
BACKUP_MK="include/kernel-defaults.mk.bak"

# 1. Определяем дистрибутив (OpenWrt/ImmortalWrt). // Determine distro type.
if grep -riq "immortalwrt" include/version.mk package/base-files/files/etc/openwrt_release 2>/dev/null; then
    DISTRO_NAME="immortalwrt"
    DOWNLOAD_DOMAIN="downloads.immortalwrt.org"
    log "Обнаружен дистрибутив: IMMORTALWRT"
else
    DISTRO_NAME="openwrt"
    DOWNLOAD_DOMAIN="downloads.openwrt.org"
    log "Обнаружен дистрибутив: OPENWRT"
fi

# 2. Пропускаем SNAPSHOT/master сборки. // Skip SNAPSHOT/master builds.
if [[ "$CLEAN_VER" == *"SNAPSHOT"* ]] || [[ "$CLEAN_VER" == *"master"* ]]; then
    warn "Сборка SNAPSHOT/Master. Vermagic Hack не применяется." # Skip hack for SNAPSHOT.
    if [ -f "$BACKUP_MK" ]; then
        log "Восстанавливаем оригинальный Makefile..." # Restoring original Makefile...
        cp -f "$BACKUP_MK" "$TARGET_MK"
    fi
else
    log "Целевая версия: $CLEAN_VER ($SRC_TARGET / $SRC_SUBTARGET)" # Target version...
    MANIFEST_URL="https://${DOWNLOAD_DOMAIN}/releases/${CLEAN_VER}/targets/${SRC_TARGET}/${SRC_SUBTARGET}/${DISTRO_NAME}-${CLEAN_VER}-${SRC_TARGET}-${SRC_SUBTARGET}.manifest"

    # 3. Скачиваем манифест. // Download manifest.
    MANIFEST_DATA=$(curl -s --fail "$MANIFEST_URL")
    if [ -z "$MANIFEST_DATA" ]; then
        warn "Манифест не найден ($MANIFEST_URL)." # Manifest not found.
    else
        # 4. Извлекаем хэш ядра (vermagic). // Extract kernel hash.
        KERNEL_HASH=$(echo "$MANIFEST_DATA" | grep -m 1 '^kernel - ' | grep -oE '[0-9a-f]{32}' | head -n 1)

        if [[ ! "$KERNEL_HASH" =~ ^[0-9a-f]{32}$ ]]; then
            err "Некорректный хэш ядра из манифеста." # Invalid kernel hash.
        else
            echo -e "${GREEN}       Официальный Vermagic Hash: $KERNEL_HASH${NC}"
            OLD_HASH=""
            [ -f "$VERMAGIC_MARKER" ] && OLD_HASH=$(cat "$VERMAGIC_MARKER")

            # 5. УМНАЯ ОЧИСТКА КЭША. // SMART CACHE CLEANING.
            if [ "$OLD_HASH" != "$KERNEL_HASH" ]; then
                warn "Хеш изменился. Глубокая очистка кэша..." # Hash changed. Deep clean...
                make target/linux/clean > /dev/null 2>&1
                rm -rf tmp/.packageinfo tmp/.targetinfo tmp/.config-target.in
                find build_dir/target-* -maxdepth 1 -type d -name "linux-*" -exec rm -rf {} + 2>/dev/null
                rm -rf staging_dir/target-*/pkginfo/kernel.default.install 2>/dev/null
                if [[ "$CLEAN_VER" == "19.07"* ]]; then rm -rf staging_dir/target-*/root-* 2>/dev/null; fi
                echo "$KERNEL_HASH" > "$VERMAGIC_MARKER"
                log "Кэши полностью сброшены." # Caches reset.
            else
                log "Хеш ядра не изменился. Кэш будет использован." # Hash unchanged. Use cache.
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
                        warn "Первый патч. Очистка CCACHE..." # First patch. Clear CCACHE.
                        [ -d "/ccache" ] && rm -rf /ccache/* 2>/dev/null
                        cp "$TARGET_MK" "$BACKUP_MK"
                    else
                        cp -f "$BACKUP_MK" "$TARGET_MK"
                    fi
                    log "Применяем Vermagic патч ($PATCH_STRATEGY)..." # Applying patch...
                    if [ "$PATCH_STRATEGY" == "legacy_md5sum" ]; then
                        sed -i "s/md5sum | cut -d ' ' -f1/echo $KERNEL_HASH/g" "$TARGET_MK"
                    else
                        sed -i "s/$SEARCH_PATTERN/echo $KERNEL_HASH/g" "$TARGET_MK"
                    fi
                    if grep -q "$KERNEL_HASH" "$TARGET_MK"; then
                        echo -e "${GREEN}       УСПЕХ: Makefile модифицирован.${NC}" # SUCCESS: Makefile modified.
                    else
                        err "Ошибка патчинга!"; exit 1
                    fi
                else
                    warn "Не удалось определить метод хэширования." # Could not detect hashing method.
                fi
            else
                err "Файл $TARGET_MK не найден."; exit 1
            fi
        fi
    fi
fi
# ======================================================================================
#  ФИНАЛ // FINAL
# ======================================================================================
log ">>> Сценарий hooks.sh завершен." # hooks.sh completed.
exit 0