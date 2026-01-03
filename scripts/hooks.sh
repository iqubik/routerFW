#!/bin/bash
# ======================================================================================
#  Pre-Build Demo file edit, Feed Manager and Hook Smart Vermagic script v1.4.1
#  File: hooks.sh
#  Description: Сценарий автоматической модификации исходного кода.
#               Запускается строго ПЕРЕД началом компиляции.
#               Включает:
#               1. Демо-автограф.
#               2. Менеджер внешних репозиториев (Feeds).
#               3. Подмену Vermagic для совместимости kmod-пакетов.
#
#  КОНТЕКСТ ВЫПОЛНЕНИЯ:
#    - Где: Корневая директория исходников (/home/build/openwrt).
#    - Когда: После скачивания фидов и настройки .config, но ДО 'make'.
#    - Статус: Локальный скрипт сборщика (НЕ попадает внутрь прошивки).
#
#  ТИПОВЫЕ ЗАДАЧИ:
#    1. Применение патчей к ядру или пакетам (patch -p1 < ...).
#    2. Редактирование файлов через sed/awk (правка Makefile, DTS, конфигов).
#    3. Скачивание сторонних файлов/блобов (curl/wget).
#    4. Условная логика на основе переменных окружения ($SRC_TARGET, $PROFILE_NAME).
# ======================================================================================

# 1. Настройка окружения и цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Вспомогательные функции логгирования
log() { echo -e "${CYAN}[HOOK]${NC} $1"; }
warn() { echo -e "${YELLOW}[HOOK] WARNING: $1${NC}"; }
err()  { echo -e "${RED}[HOOK] ERROR: $1${NC}"; }

log ">>> Запуск сценария hooks.sh (Universal v1.4.1)..."

# ======================================================================================
# БЛОК 1: Демонстрационный пример (Автограф в README)
# ======================================================================================
# Этот блок показывает, как безопасно модифицировать файл.
TARGET_FILE=$(find . -maxdepth 1 -name "README*" | head -n 1)
[ -z "$TARGET_FILE" ] && TARGET_FILE="README.md" && touch "$TARGET_FILE"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
SIGNATURE="Build processed by SourceBuilder"

# Проверка на идемпотентность
if ! grep -Fq "$SIGNATURE" "$TARGET_FILE"; then
    log "Добавляем автограф в $TARGET_FILE..."
    echo "" >> "$TARGET_FILE"
    echo "--- $SIGNATURE on $TIMESTAMP ---" >> "$TARGET_FILE"
    
    # Валидация записи
    if grep -Fq "$SIGNATURE" "$TARGET_FILE"; then
        echo -e "${GREEN}       УСПЕХ: README обновлен.${NC}"
        echo -e "${CYAN}       Содержимое последней строки:${NC}"
        tail -n 1 "$TARGET_FILE"
    else
        err "Не удалось записать в файл!"
        exit 1
    fi
fi

# ======================================================================================
# БЛОК 2: Smart Feed Manager (Добавление внешних репозиториев)
# ======================================================================================
log ">>> Проверка и интеграция внешних фидов (Feeds)..."

# Функция для безопасного добавления и установки фида
add_feed() {
    local FEED_NAME="$1"
    local FEED_URL="$2"
    local FEED_FILE="feeds.conf.default"

    # Проверяем, есть ли уже такой фид (по имени или URL)
    if grep -qE "^src-git ${FEED_NAME} " "$FEED_FILE" || grep -Fq "$FEED_URL" "$FEED_FILE"; then
        log "Фид '$FEED_NAME' уже присутствует. Пропуск."
    else
        log "Добавляем фид: $FEED_NAME -> $FEED_URL"
        echo "src-git ${FEED_NAME} ${FEED_URL}" >> "$FEED_FILE"

        # Принудительно обновляем и устанавливаем пакеты ТОЛЬКО из этого фида
        # Это критически важно, так как основной update уже прошел до запуска хука
        log "Интеграция пакетов из $FEED_NAME..."
        
        ./scripts/feeds update "$FEED_NAME"
        if [ $? -eq 0 ]; then
            ./scripts/feeds install -a -p "$FEED_NAME"
            echo -e "${GREEN}       УСПЕХ: Пакеты из $FEED_NAME установлены в дерево сборки.${NC}"
        else
            err "Не удалось обновить фид $FEED_NAME. Проверьте URL или сеть."
            # Не делаем exit 1, чтобы не ломать всю сборку из-за одного фида, но предупреждаем
        fi
    fi
}

# --- СПИСОК РЕПОЗИТОРИЕВ ДЛЯ ДОБАВЛЕНИЯ ---
# Здесь вы можете добавлять любые необходимые репозитории

# 1. AmneziaWG (Для протокола Amnezia)
add_feed "amneziawg" "https://github.com/amnezia-vpn/amnezia-wg-openwrt.git"

# 2. OpenClash / SSClash (Если нужны специфичные версии, раскомментируйте)
# add_feed "openclash" "https://github.com/vernesong/OpenClash.git"

# 3. Дополнительные пакеты (Kenzok8/Small - содержит ssclash, passwall и кучу всего)
# Внимание: может конфликтовать со стандартными пакетами, использовать аккуратно!
# add_feed "small" "https://github.com/kenzok8/small-package"

# ======================================================================================
# БЛОК 3: Vermagic Hack + SMART CACHE CLEAN (OpenWrt & ImmortalWrt)
# ======================================================================================
log ">>> Проверка необходимости Vermagic Hack..."

# 1. Очистка версии
CLEAN_VER=$(echo "$SRC_BRANCH" | sed 's/^v//')
VERMAGIC_MARKER=".last_vermagic"
TARGET_MK="include/kernel-defaults.mk"
BACKUP_MK="include/kernel-defaults.mk.bak"

# 2. Определение дистрибутива (OpenWrt или ImmortalWrt)
if grep -riq "immortalwrt" include/version.mk package/base-files/files/etc/openwrt_release 2>/dev/null; then
    DISTRO_NAME="immortalwrt"
    DOWNLOAD_DOMAIN="downloads.immortalwrt.org"
    log "Обнаружен дистрибутив: IMMORTALWRT"
else
    DISTRO_NAME="openwrt"
    DOWNLOAD_DOMAIN="downloads.openwrt.org"
    log "Обнаружен дистрибутив: OPENWRT"
fi

# Проверка на SNAPSHOT/Master
if [[ "$CLEAN_VER" == *"SNAPSHOT"* ]] || [[ "$CLEAN_VER" == *"master"* ]]; then
    warn "Сборка SNAPSHOT/Master. Vermagic Hack не применяется."
    # Если файл был патчен ранее, восстанавливаем оригинал
    if [ -f "$BACKUP_MK" ]; then
        # Проверяем, не патчен ли уже файл (используем безопасную проверку)
        if grep -q "echo [0-9a-f]\{32\}" "$TARGET_MK" 2>/dev/null; then
            log "Восстанавливаем оригинальный Makefile..."
            cp -f "$BACKUP_MK" "$TARGET_MK"
        fi
    fi
else
    log "Целевая версия: $CLEAN_VER ($SRC_TARGET / $SRC_SUBTARGET)"

    # 3. Формирование универсального URL
    MANIFEST_URL="https://${DOWNLOAD_DOMAIN}/releases/${CLEAN_VER}/targets/${SRC_TARGET}/${SRC_SUBTARGET}/${DISTRO_NAME}-${CLEAN_VER}-${SRC_TARGET}-${SRC_SUBTARGET}.manifest"
    
    log "Скачиваем манифест: $MANIFEST_URL"
    MANIFEST_DATA=$(curl -s --fail "$MANIFEST_URL")
    
    if [ $? -ne 0 ] || [ -z "$MANIFEST_DATA" ]; then
        err "Не удалось скачать манифест (404 Not Found или сеть). Пропуск."
    else
        # 4. Извлечение хэша (32 hex символа)
        KERNEL_HASH=$(echo "$MANIFEST_DATA" | grep -m 1 '^kernel - ' | grep -oE '[0-9a-f]{32}' | head -n 1)

        # Валидация хэша
        if [[ ! "$KERNEL_HASH" =~ ^[0-9a-f]{32}$ ]]; then
            err "Некорректный хэш ядра: '$KERNEL_HASH'"
            exit 1
        else
            echo -e "${GREEN}       Официальный Vermagic Hash: $KERNEL_HASH${NC}"

            # 5. Smart Cache Cleaning (Enhanced for v19.07 + Modern)
            OLD_HASH=""
            [ -f "$VERMAGIC_MARKER" ] && OLD_HASH=$(cat "$VERMAGIC_MARKER")

            if [ "$OLD_HASH" != "$KERNEL_HASH" ]; then
                warn "Хеш изменился ($OLD_HASH -> $KERNEL_HASH). Глубокая очистка..."
                # 1. Мягкая очистка через make
                make target/linux/clean > /dev/null 2>&1
                # 2. Удаление временных файлов конфигурации (Критично для 19.07)
                rm -rf tmp/.packageinfo tmp/.targetinfo tmp/.config-target.in
                # 3. Удаление артефактов ядра в build_dir
                find build_dir/target-* -maxdepth 1 -type d -name "linux-*" -exec rm -rf {} + 2>/dev/null
                # 4. Удаление штампов установки ядра (чтобы заставить систему пересчитать vermagic)
                rm -rf staging_dir/target-*/pkginfo/kernel.default.install 2>/dev/null
                # 5. Если это ветка 19.07 — чистим staging_dir более точечно
                if [[ "$CLEAN_VER" == "19.07"* ]]; then
                    rm -rf staging_dir/target-*/root-* 2>/dev/null
                fi
                # Сохраняем новый хеш
                echo "$KERNEL_HASH" > "$VERMAGIC_MARKER"
                log "Кэши полностью сброшены. Готово к чистой сборке ядра."
            else
                log "Хеш ядра не изменился ($KERNEL_HASH). Используем кэш."
            fi

            # 6. Патчинг Makefile
            if [ -f "$TARGET_MK" ]; then
                # Определение типа синтаксиса в файле
                PATCH_STRATEGY=""
                
                # Стратегия 1: Современный OpenWrt (>= 21.02)
                if grep -Fq '$(MKHASH) md5' "$TARGET_MK"; then
                    PATCH_STRATEGY="modern"
                    SEARCH_PATTERN='\$(MKHASH) md5'
                # Стратегия 2: Старый OpenWrt (19.07 и старее) - прямой вызов mkhash
                elif grep -Fq 'mkhash md5' "$TARGET_MK"; then
                    PATCH_STRATEGY="legacy_mkhash"
                    SEARCH_PATTERN='mkhash md5'
                # Стратегия 3: Древний OpenWrt или форки - использование md5sum
                elif grep -Fq 'md5sum' "$TARGET_MK" && grep -Fq '.vermagic' "$TARGET_MK"; then
                    PATCH_STRATEGY="legacy_md5sum"
                    # Тут сложнее, нужно заменить пайплайн
                    SEARCH_PATTERN='md5sum | cut -d . .'
                fi

                # Если стратегия не найдена, но есть бэкап - возможно файл уже патчен
                if [ -z "$PATCH_STRATEGY" ] && [ -f "$BACKUP_MK" ]; then
                    log "Синтаксис не найден, но есть бэкап. Восстанавливаем..."
                    cp -f "$BACKUP_MK" "$TARGET_MK"
                    # Пробуем определить снова после восстановления
                    if grep -Fq '$(MKHASH) md5' "$TARGET_MK"; then PATCH_STRATEGY="modern"; SEARCH_PATTERN='\$(MKHASH) md5';
                    elif grep -Fq 'mkhash md5' "$TARGET_MK"; then PATCH_STRATEGY="legacy_mkhash"; SEARCH_PATTERN='mkhash md5';
                    fi
                fi

                if [ -n "$PATCH_STRATEGY" ]; then
                    # Логика бэкапа и CCACHE (как в оригинале)
                    if [ ! -f "$BACKUP_MK" ]; then
                        warn "Обнаружен переход из unpatched состояния. Очистка CCACHE..."
                        if [ -d "/ccache" ]; then rm -rf /ccache/* 2>/dev/null || true; fi
                        cp "$TARGET_MK" "$BACKUP_MK"
                    else
                        # Всегда восстанавливаем из бэкапа перед новым патчем, чтобы избежать наслоений
                        cp -f "$BACKUP_MK" "$TARGET_MK"
                    fi

                    log "Применяем Vermagic патч ($PATCH_STRATEGY) к $TARGET_MK..."
                    
                    if [ "$PATCH_STRATEGY" == "legacy_md5sum" ]; then
                        # Для совсем старых версий заменяем пайплайн md5sum
                        sed -i "s/md5sum | cut -d ' ' -f1/echo $KERNEL_HASH/g" "$TARGET_MK"
                    else
                        # Для Modern и Legacy (mkhash) замена одинакова по сути
                        sed -i "s/$SEARCH_PATTERN/echo $KERNEL_HASH/g" "$TARGET_MK"
                    fi
                    
                    # Финальная проверка
                    if grep -q "$KERNEL_HASH" "$TARGET_MK"; then
                        echo -e "${GREEN}       УСПЕХ: Makefile модифицирован для версии $CLEAN_VER.${NC}"
                    else
                        err "Ошибка патчинга! Хэш не найден после замены."
                        exit 1
                    fi
                else
                    warn "Не удалось определить метод хэширования в $TARGET_MK."
                    warn "Патчинг пропущен (Безопасный режим)."
                fi
            else
                err "Файл $TARGET_MK не найден."
                exit 1
            fi
        fi
    fi
fi

# ======================================================================================
# ФИНАЛ
# ======================================================================================
log ">>> Сценарий hooks.sh завершен корректно."
exit 0