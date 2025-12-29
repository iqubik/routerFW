#!/bin/bash
# ======================================================================================
#  Pre-Build Demo file edit and Hook Smart Vermagic script v1.0 (by spamroot)
#  File: hooks.sh
#  Description: Сценарий автоматической модификации исходного кода.
#               Запускается строго ПЕРЕД началом компиляции. Скрипт домфикации vermagic
#               позволяет собирать kmod-пакеты из официального репозитория OpenWrt.
# ======================================================================================
#
#  КОНТЕКСТ ВЫПОЛНЕНИЯ:
#    - Где: Корневая директория исходников OpenWrt (/home/build/openwrt).
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

log ">>> Запуск сценария hooks.sh..."

# ======================================================================================
# БЛОК 1: Демонстрационный пример (Автограф в README)
# ======================================================================================
# Этот блок показывает, как безопасно модифицировать файл.
TARGET_FILE=$(find . -maxdepth 1 -name "README*" | head -n 1)

if [ -z "$TARGET_FILE" ]; then
    warn "Файл README не найден! Создаем новый."
    TARGET_FILE="README.md"
    touch "$TARGET_FILE"
fi

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
SIGNATURE="Build processed by SourceBuilder"

# Проверка на идемпотентность (чтобы не дублировать строки при повторном запуске)
if grep -Fq "$SIGNATURE" "$TARGET_FILE"; then
    log "Автограф уже присутствует в $TARGET_FILE. Пропускаем."
else
    log "Добавляем автограф в $TARGET_FILE..."
    echo "" >> "$TARGET_FILE"
    echo "--- $SIGNATURE on $TIMESTAMP ---" >> "$TARGET_FILE"
    
    # Валидация (то, что я убрал зря)
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
# БЛОК 2: Vermagic Hack + SMART CACHE CLEAN
# ======================================================================================
# Позволяет устанавливать kmod-пакеты из официального репозитория.
# Работает только для релизов (TAGS), для SNAPSHOT/Master пропускается.
log ">>> Проверка необходимости Vermagic Hack..."

# 1. Очистка версии (убираем 'v' в начале)
CLEAN_VER=$(echo "$SRC_BRANCH" | sed 's/^v//')
VERMAGIC_MARKER=".last_vermagic"

# 2. Проверка условий (безопасность)
if [[ "$CLEAN_VER" == *"SNAPSHOT"* ]] || [[ "$CLEAN_VER" == *"master"* ]]; then
    warn "Сборка SNAPSHOT/Master. Vermagic Hack не применяется."
else
    log "Целевая версия: $CLEAN_VER ($SRC_TARGET / $SRC_SUBTARGET)"
    # 3. Формирование URL манифеста
    
    MANIFEST_URL="https://downloads.openwrt.org/releases/${CLEAN_VER}/targets/${SRC_TARGET}/${SRC_SUBTARGET}/openwrt-${CLEAN_VER}-${SRC_TARGET}-${SRC_SUBTARGET}.manifest"
    
    log "Скачиваем манифест: $MANIFEST_URL"
    MANIFEST_DATA=$(curl -s --fail "$MANIFEST_URL")
    
    if [ $? -ne 0 ] || [ -z "$MANIFEST_DATA" ]; then
        err "Не удалось скачать манифест. Проверьте сеть или версию."
        # Можно exit 1, если критично
    else
        # 4. Извлечение хэша
        KERNEL_HASH=$(echo "$MANIFEST_DATA" | grep -m 1 '^kernel - ' | grep -oE '[0-9a-f]{32}' | head -n 1)

        # Валидация хэша (строго 32 hex символа)
        if [[ ! "$KERNEL_HASH" =~ ^[0-9a-f]{32}$ ]]; then
            err "Некорректный хэш ядра: '$KERNEL_HASH'"
            exit 1
        else
            echo -e "${GREEN}       Официальный Vermagic Hash: $KERNEL_HASH${NC}"

            # 5. Патчинг include/kernel-defaults.mk
            # --- SMART CACHE CLEANING ---
            # Проверяем, с каким хешем мы собирали в прошлый раз
            OLD_HASH=""
            if [ -f "$VERMAGIC_MARKER" ]; then
                OLD_HASH=$(cat "$VERMAGIC_MARKER")
            fi

            if [ "$OLD_HASH" != "$KERNEL_HASH" ]; then
                warn "Обнаружено изменение хеша ядра ($OLD_HASH -> $KERNEL_HASH)!"
                log "Выполняем очистку ядра (make target/linux/clean), чтобы применить новый Vermagic..."
                
                # 1. Мягкая очистка через make (сбрасывает флаги компиляции ядра)
                make target/linux/clean > /dev/null 2>&1
                
                # 2. Жесткая очистка артефактов ядра (удаляем папки linux-* в build_dir)
                # Это гарантирует, что ядро пересоберется с новым хэшем.
                # При этом toolchain (gcc) НЕ удаляется, экономим время.
                find build_dir/target-* -maxdepth 1 -type d -name "linux-*" -exec rm -rf {} + 2>/dev/null
                
                # Сохраняем новый хеш
                echo "$KERNEL_HASH" > "$VERMAGIC_MARKER"
                log "Кэш ядра очищен. Готово к пересборке."
            else
                log "Хеш ядра не изменился ($KERNEL_HASH). Использем кэш."
            fi
            # -----------------------------

            # Патчим Makefile
            TARGET_MK="include/kernel-defaults.mk"
            if [ -f "$TARGET_MK" ]; then
                log "Применяем патч к $TARGET_MK..."
                # Заменяем вычисление хэша $(MKHASH) md5 на жесткий echo ХЭШ
                sed -i "s/\$(MKHASH) md5/echo $KERNEL_HASH/g" "$TARGET_MK"
                # Проверка
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