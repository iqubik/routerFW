#!/bin/sh
# Professional Extroot Setup Script for OpenWrt v1.3 (Audited & Debuggable)
# Добавлена переменная для версионирования и улучшено логирование

# === CONFIGURATION ===
DISK="/dev/mmcblk0"
PART_ROOT="${DISK}p6"
PART_SWAP="${DISK}p7"
SWAP_SIZE_GB="2"
VERSION="1.3"
# =====================

fail() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
    exit 1
}

info() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

info "--- Запуск Professional Extroot Script v${VERSION} ---"
info "Целевой диск: ${DISK}"

# 1. Проверка зависимостей
info "[Этап 1/4] Проверка зависимостей..."
PKGS=""
command -v blkid >/dev/null || PKGS="$PKGS blkid"
# Проверяем наличие пакета block-mount (критично)
if ! opkg list-installed | grep -q block-mount; then
    PKGS="$PKGS block-mount"
fi
# Проверяем fdisk
command -v fdisk >/dev/null || PKGS="$PKGS fdisk"

if [ -n "$PKGS" ]; then
    info "--> Установка недостающих пакетов: $PKGS"
    opkg update
    opkg install $PKGS || fail "Не удалось установить пакеты."
else
    info "--> Все зависимости на месте."
fi
info "[Этап 1/4] Зависимости в порядке."

# 2. Разметка диска (Математический метод)
info "[Этап 2/4] Проверка разметки диска..."
if ! [ -b "$PART_SWAP" ]; then
    info "--> Раздел ${PART_SWAP} не найден. Требуется разметка."
    info "--> НАЧАЛО РАЗМЕТКИ ДИСКА..."
    
    # Получаем размер диска в секторах (из sysfs - это самый надежный способ)
    DISK_NAME=${DISK##*/}
    TOTAL_SECTORS=$(cat /sys/class/block/${DISK_NAME}/size)
    # Размер сектора (обычно 512)
    SECTOR_SIZE=$(cat /sys/class/block/${DISK_NAME}/queue/hw_sector_size 2>/dev/null || echo 512)
    # Вычисляем размер SWAP в секторах: (GB * 1024^3) / SectorSize
    # Используем awk для расчетов, так как sh не умеет в большие числа иногда
    SWAP_SECTORS=$(awk "BEGIN {print int($SWAP_SIZE_GB * 1024 * 1024 * 1024 / $SECTOR_SIZE)}")
    # Вычисляем начало раздела SWAP (Оставляем небольшой отступ с конца, если нужно, но обычно Total - Swap)
    SWAP_START=$(awk "BEGIN {print $TOTAL_SECTORS - $SWAP_SECTORS}")
    # Конец раздела ROOT (перед SWAP)
    ROOT_END=$(awk "BEGIN {print $SWAP_START - 1}")
    
    # Генерируем команды для fdisk
    # d 6, d 7 (на всякий случай), n p 6 (default start) (calculated end), n p 7 (calculated start) (default end)
    # Используем wipefs если есть, или надеемся на fdisk. 
    # Чтобы избежать вопросов про сигнатуры, можно затереть начало разделов dd, но это опасно для активной системы.
    # Просто передаем 'Y' на случай вопроса о сигнатуре.
    
    # Формируем сложную последовательность с потенциальными 'Y' для подтверждения удаления сигнатур
    # Команды:
    # d -> 6
    # d -> 7 (игнорируем ошибку если нет)
    # n -> (p) -> 6 -> (default start) -> $ROOT_END
    # n -> (p) -> 7 -> (default start) -> (default end)
    # w
    info "--> Геометрия диска: Total=${TOTAL_SECTORS}, SwapStart=${SWAP_START}, RootEnd=${ROOT_END}"
    
    (
        echo d; echo 6
        echo d; echo 7
        echo n; echo p; echo 6; echo; echo "$ROOT_END"
        echo Y; # Ответ "Yes" если спросит про сигнатуру ext4
        echo n; echo p; echo 7; echo; echo
        echo Y; # Ответ "Yes" если спросит про сигнатуру swap
        echo w
    ) | fdisk "$DISK"
    
    info "--> РАЗМЕТКА ДИСКА ЗАВЕРШЕНА."
    info "--> Таблица разделов обновлена. Требуется перезагрузка ядра."
    sleep 3
    reboot
    exit 0
else
    info "--> Разделы уже существуют. Пропускаем разметку."
fi
info "[Этап 2/4] Разметка диска в порядке."


# 3. Форматирование
info "[Этап 3/4] Проверка файловых систем..."
if ! blkid "$PART_ROOT" | grep -q 'TYPE="ext4"'; then
    # -F force (избегает вопросов)
    info "--> Раздел ${PART_ROOT} не отформатирован. Форматирование в ext4..."
    mkfs.ext4 -F -L emmc_data "$PART_ROOT" || fail "Ошибка форматирования ext4"
    info "--> Форматирование ${PART_ROOT} завершено."
else
    info "--> Раздел ${PART_ROOT} уже отформатирован в ext4."
fi

if ! blkid "$PART_SWAP" | grep -q 'TYPE="swap"'; then
    info "--> Раздел ${PART_SWAP} не отформатирован. Создание swap..."
    mkswap "$PART_SWAP" || fail "Ошибка создания swap"
    info "--> Создание swap на ${PART_SWAP} завершено."
else
    info "--> Раздел ${PART_SWAP} уже является swap."
fi
info "[Этап 3/4] Файловые системы в порядке."


# 4. Настройка Extroot
info "[Этап 4/4] Проверка активации Extroot..."
CURRENT_OVERLAY_DEV=$(mount | grep 'on /overlay ' | awk '{print $1}')

if [ "$CURRENT_OVERLAY_DEV" != "$PART_ROOT" ]; then
    info "--> Extroot не активен на ${PART_ROOT}. Запуск финальной настройки..."

    UUID_ROOT=$(blkid -o value -s UUID "$PART_ROOT")
    [ -z "$UUID_ROOT" ] && fail "Не удалось получить UUID для $PART_ROOT"
    info "--> UUID для ${PART_ROOT} найден: ${UUID_ROOT}"
    
    MNT="/mnt/new_extroot"
    mkdir -p "$MNT"
    info "--> Монтирование ${PART_ROOT} в ${MNT}..."
    mount "$PART_ROOT" "$MNT" || fail "Не удалось смонтировать $PART_ROOT"

    info "--> Копирование данных из /overlay в ${MNT}..."
    tar -C /overlay -cvf - . | tar -C "$MNT" -xf -

    # Детекция пути конфига
    if [ -d "$MNT/upper/etc/config" ]; then
        CFG_PATH="$MNT/upper/etc/config"
    elif [ -d "$MNT/etc/config" ]; then
        CFG_PATH="$MNT/etc/config"
    else
        mkdir -p "$MNT/etc/config"
        CFG_PATH="$MNT/etc/config"
        [ ! -f "$CFG_PATH/fstab" ] && cp /etc/config/fstab "$CFG_PATH/"
    fi
    info "--> Путь к конфигурационным файлам определен: ${CFG_PATH}"
    
    # Очистка старых анонимных маунтов для надежности (итерация)
    # Удаляем все записи, у которых target /overlay, чтобы не было дублей
    # (Это сложная логика для shell, поэтому используем простой метод именованной перезаписи
    # и надеемся, что block-mount приоритезирует UUID)
    info "--> Модификация fstab внутри нового раздела..."
    uci -c "$CFG_PATH" batch <<EOF
set fstab.overlay=mount
set fstab.overlay.uuid='$UUID_ROOT'
set fstab.overlay.target='/overlay'
set fstab.overlay.enabled='1'
set fstab.swap=swap
set fstab.swap.device='$PART_SWAP'
set fstab.swap.enabled='1'
commit fstab
EOF

    info "--> Отмонтирование ${MNT}..."
    umount "$MNT"
    
    info "--> Настройка завершена успешно. Финальная перезагрузка."
    reboot
    exit 0
else
    info "--> Extroot уже активен на ${PART_ROOT}. Никаких действий не требуется."
fi
info "[Этап 4/4] Extroot в порядке."

info "--- Скрипт настройки Extroot завершил работу. ---"
exit 0
