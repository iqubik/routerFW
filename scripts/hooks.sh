#!/bin/bash
# ======================================================================================
#  Pre-Build Demo file edit and Hook Smart Vermagic script v1.3.2 (Universal)
#  File: hooks.sh
#  Description: Сценарий автоматической модификации исходного кода.
#               Запускается строго ПЕРЕД началом компиляции. Скрипт подмены vermagic
#               позволяет собирать kmod-пакеты совместимые с официальными репозиториями.
#               Поддерживает OpenWrt и ImmortalWrt.
# ======================================================================================
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
#
#  УПРАВЛЕНИЕ СБОРКОЙ:
#    exit 0 -> Успех, продолжить сборку.
#    exit 1 -> Критическая ошибка, немедленно остановить сборку.
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

log ">>> Запуск сценария hooks.sh (Universal)..."

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
# БЛОК 2: Vermagic Hack + SMART CACHE CLEAN (OpenWrt & ImmortalWrt)
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
        # Проверяем, не патчен ли уже файл
        if ! grep -Fq '$(MKHASH) md5' "$TARGET_MK"; then
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

        # Валидация хэша (строго 32 hex символа)
        if [[ ! "$KERNEL_HASH" =~ ^[0-9a-f]{32}$ ]]; then
            err "Некорректный хэш ядра: '$KERNEL_HASH'"
            exit 1
        else
            echo -e "${GREEN}       Официальный Vermagic Hash: $KERNEL_HASH${NC}"

            # 5. Smart Cache Cleaning
            OLD_HASH=""
            [ -f "$VERMAGIC_MARKER" ] && OLD_HASH=$(cat "$VERMAGIC_MARKER")

            if [ "$OLD_HASH" != "$KERNEL_HASH" ]; then
                warn "Хеш изменился ($OLD_HASH -> $KERNEL_HASH). Очистка ядра..."
                # Мягкая очистка флагов
                make target/linux/clean > /dev/null 2>&1
                # Удаление скомпилированных артефактов ядра
                find build_dir/target-* -maxdepth 1 -type d -name "linux-*" -exec rm -rf {} + 2>/dev/null
                
                # Сохраняем новый хеш
                echo "$KERNEL_HASH" > "$VERMAGIC_MARKER"
                log "Кэш ядра очищен. Готово к пересборке."
            else
                log "Хеш ядра не изменился ($KERNEL_HASH). Используем кэш."
            fi
            # -----------------------------

            # 6. Патчинг Makefile (Git-Safe)
            if [ -f "$TARGET_MK" ]; then
                # 6.1. Проверка перехода из unpatched состояния (ДО патчинга!)
                if [ -f "$BACKUP_MK" ]; then
                    # Бэкап существует - значит мы УЖЕ патчили ранее
                    log "Makefile уже был патчен ранее. Пропускаем CCACHE clean."
                else
                    # Бэкапа нет - это ПЕРВЫЙ запуск патча после отката
                    warn "Обнаружен переход из unpatched состояния. Очистка CCACHE..."
                    if [ -d "/ccache" ]; then
                        rm -rf /ccache/* 2>/dev/null || true
                        log "CCACHE очищен для чистой сборки с патчем."
                    fi
                fi

                # 6.2. Проверка целостности файла перед патчингом
                if grep -Fq '$(MKHASH) md5' "$TARGET_MK"; then
                    # Файл чистый - делаем бэкап
                    cp "$TARGET_MK" "$BACKUP_MK"
                elif [ -f "$BACKUP_MK" ]; then
                    # Файл грязный - восстанавливаем из бэкапа
                    cp -f "$BACKUP_MK" "$TARGET_MK"
                else
                    err "Makefile изменен и бэкапа нет."
                    exit 1
                fi

                log "Применяем Vermagic патч к $TARGET_MK..."
                sed -i "s/\$(MKHASH) md5/echo $KERNEL_HASH/g" "$TARGET_MK"                
                
                # Финальная проверка
                if grep -q "$KERNEL_HASH" "$TARGET_MK"; then
                    echo -e "${GREEN}       УСПЕХ: Makefile модифицирован. Ядро соберется с официальным хэшем.${NC}"
                else
                    err "Ошибка патчинга Makefile."
                    exit 1
                fi
            else
                err "Файл $TARGET_MK не найден. Структура исходников изменилась?"
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