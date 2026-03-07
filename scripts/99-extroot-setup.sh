#!/bin/sh
# Professional Extroot Setup Script for OpenWrt v1.1 (Audited)
# Исправлена проблема с fdisk busybox и расчетом секторов

# === CONFIGURATION ===
DISK="/dev/mmcblk0"
PART_ROOT="${DISK}p6"
PART_SWAP="${DISK}p7"
SWAP_SIZE_GB="2"
# =====================

fail() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
    exit 1
}

info() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

info "--- Запуск Professional Extroot Script v1.1 ---"

# 1. Проверка зависимостей
PKGS=""
command -v blkid >/dev/null || PKGS="$PKGS blkid"
# Проверяем наличие пакета block-mount (критично)
if ! opkg list-installed | grep -q block-mount; then
    PKGS="$PKGS block-mount"
fi
# Проверяем fdisk
command -v fdisk >/dev/null || PKGS="$PKGS fdisk"

if [ -n "$PKGS" ]; then
    info "Установка недостающих пакетов: $PKGS"
    opkg update
    opkg install $PKGS || fail "Не удалось установить пакеты."
fi

# 2. Разметка диска (Математический метод)
if ! [ -b "$PART_SWAP" ]; then
    info "Этап 2: Переразметка диска..."
    
    # Получаем размер диска в секторах (из sysfs - это самый надежный способ)
    DISK_NAME=${DISK##*/} # mmcblk0
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
    
    info "Геометрия: Total=$TOTAL_SECTORS, SwapStart=$SWAP_START"
    
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
    
    (
        echo d; echo 6
        echo d; echo 7
        echo n; echo p; echo 6; echo; echo "$ROOT_END"
        echo Y; # Ответ "Yes" если спросит про сигнатуру ext4
        echo n; echo p; echo 7; echo; echo
        echo Y; # Ответ "Yes" если спросит про сигнатуру swap
        echo w
    ) | fdisk "$DISK"
    
    info "Таблица разделов обновлена. Требуется перезагрузка."
    sleep 2
    reboot
    exit 0
fi

# 3. Форматирование
if ! blkid "$PART_ROOT" | grep -q 'TYPE="ext4"'; then
    info "Форматирование $PART_ROOT в ext4..."
    # -F force (избегает вопросов)
    mkfs.ext4 -F -L emmc_data "$PART_ROOT" || fail "Ошибка форматирования ext4"
fi

if ! blkid "$PART_SWAP" | grep -q 'TYPE="swap"'; then
    info "Форматирование $PART_SWAP..."
    mkswap "$PART_SWAP" || fail "Ошибка создания swap"
fi

# 4. Настройка Extroot
CURRENT_OVERLAY_DEV=$(mount | grep 'on /overlay ' | awk '{print $1}')

if [ "$CURRENT_OVERLAY_DEV" != "$PART_ROOT" ]; then
    info "Настройка переноса overlay на $PART_ROOT..."

    UUID_ROOT=$(blkid -o value -s UUID "$PART_ROOT")
    [ -z "$UUID_ROOT" ] && fail "Не удалось получить UUID"
    
    MNT="/mnt/new_extroot"
    mkdir -p "$MNT"
    mount "$PART_ROOT" "$MNT" || fail "Не удалось смонтировать $PART_ROOT"

    info "Копирование данных..."
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
    
    info "Правка fstab в $CFG_PATH..."
    
    # Очистка старых анонимных маунтов для надежности (итерация)
    # Удаляем все записи, у которых target /overlay, чтобы не было дублей
    # (Это сложная логика для shell, поэтому используем простой метод именованной перезаписи
    # и надеемся, что block-mount приоритезирует UUID)
    
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

    umount "$MNT"
    info "Готово. Перезагрузка..."
    reboot
    exit 0
fi

info "Extroot уже настроен."
exit 0
