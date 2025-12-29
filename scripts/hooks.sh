#!/bin/bash
# ВАЖНО: ЭТОТ ФАЙЛ ДОЛЖЕН ИМЕТЬ КОДИРОВКУ КОНЦА СТРОК LF (UNIX)!
# VSCode: Снизу справа кликнуть "CRLF" -> выбрать "LF".
# Notepad++: Правка -> Формат конца строки -> UNIX (LF).

# ==============================================================================
#  OpenWrt SourceBuilder: Pre-Build Hook
#  File: hooks.sh
#  Description: Сценарий автоматической модификации исходного кода.
#               Запускается строго ПЕРЕД началом компиляции.
# ==============================================================================
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
# ==============================================================================

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

# ==============================================================================
# БЛОК 1: Демонстрационный пример (Автограф в README)
# ==============================================================================
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
    
    # Валидация
    if grep -Fq "$SIGNATURE" "$TARGET_FILE"; then
        echo -e "${GREEN}       УСПЕХ: README обновлен.${NC}"
    else
        err "Не удалось записать в файл!"
        exit 1
    fi
fi

# ==============================================================================
# БЛОК 2: Vermagic Hack (Синхронизация хэша ядра с официальным)
# ==============================================================================
# Позволяет устанавливать kmod-пакеты из официального репозитория.
# Работает только для релизов (TAGS), для SNAPSHOT/Master пропускается.

log ">>> Проверка необходимости Vermagic Hack..."

# 1. Очистка версии (убираем 'v' в начале)
CLEAN_VER=$(echo "$SRC_BRANCH" | sed 's/^v//')

# 2. Проверка условий (безопасность)
if [[ "$CLEAN_VER" == *"SNAPSHOT"* ]] || [[ "$CLEAN_VER" == *"master"* ]]; then
    warn "Сборка SNAPSHOT или Master. Подмена Vermagic невозможна."
    warn "Пропускаем этот шаг."
else
    log "Целевая версия: $CLEAN_VER ($SRC_TARGET / $SRC_SUBTARGET)"

    # 3. Формирование URL манифеста
    MANIFEST_URL="https://downloads.openwrt.org/releases/${CLEAN_VER}/targets/${SRC_TARGET}/${SRC_SUBTARGET}/openwrt-${CLEAN_VER}-${SRC_TARGET}-${SRC_SUBTARGET}.manifest"
    
    log "Скачиваем манифест: $MANIFEST_URL"
    MANIFEST_DATA=$(curl -s --fail "$MANIFEST_URL")
    CURL_EXIT=$?

    if [ $CURL_EXIT -ne 0 ] || [ -z "$MANIFEST_DATA" ]; then
        err "Не удалось скачать манифест (Код ошибки curl: $CURL_EXIT)."
        err "Проверьте интернет или правильность версии/таргета в профиле."
        # Если критично совпадение с репо - расскоментируйте exit 1
        # exit 1 
    else
        # 4. Извлечение хэша
        # Ищем строку вида: "kernel - 5.15.x-1-HASH"
        KERNEL_HASH=$(echo "$MANIFEST_DATA" | grep -m 1 '^kernel - ' | sed -E 's/.*-([0-9a-f]{32})/\1/')

        # Валидация хэша (строго 32 hex символа)
        if [[ ! "$KERNEL_HASH" =~ ^[0-9a-f]{32}$ ]]; then
            err "Получен некорректный хэш: '$KERNEL_HASH'"
            exit 1
        else
            echo -e "${GREEN}       Официальный Vermagic Hash: $KERNEL_HASH${NC}"

            # 5. Патчинг include/kernel-defaults.mk
            TARGET_MK="include/kernel-defaults.mk"
            
            if [ -f "$TARGET_MK" ]; then
                log "Применяем патч к $TARGET_MK..."
                
                # Заменяем вычисление хэша $(MKHASH) md5 на жесткий echo ХЭШ
                sed -i "s/\$(MKHASH) md5/echo $KERNEL_HASH/g" "$TARGET_MK"
                
                # Проверка
                if grep -q "$KERNEL_HASH" "$TARGET_MK"; then
                    echo -e "${GREEN}       УСПЕХ: Makefile модифицирован. Ядро соберется с официальным хэшем.${NC}"
                else
                    err "Sed выполнился, но замена не найдена в файле."
                    exit 1
                fi
            else
                err "Файл $TARGET_MK не найден. Структура исходников изменилась?"
                exit 1
            fi
        fi
    fi
fi

# ==============================================================================
# ФИНАЛ
# ==============================================================================
log ">>> Сценарий hooks.sh завершен корректно."
exit 0