#!/bin/sh
# Extroot Setup Script for OpenWrt
# (Оптимизировано для uci-defaults)
#
# АРХИТЕКТУРА:
# Этот скрипт реализует надежную 3-х уровневую разметку для систем с большим накопителем:
# 1. Системный раздел (p6): Небольшой (4ГБ) раздел ext4 для extroot (overlay).
#    Он хранит конфигурацию системы и установленные пакеты, изолируя их от данных пользователя.
# 2. Раздел данных (p7): Большой раздел ext4, занимающий основную часть оставшегося места.
#    Монтируется в /mnt/data и служит центральным хранилищем для "тяжелых" приложений,
#    таких как Docker, торренты и т.д.
# 3. Раздел подкачки (p8): Выделенный раздел для swap.
#
# КЛЮЧЕВЫЕ ОСОБЕННОСТИ:
# - Полная автоматизация: Рассчитан на однократный запуск ("fire-and-forget") на чистой системе.
# - Идемпотентность: Может быть запущен многократно без ошибок; он обнаружит
#   уже настроенную систему и корректно завершит работу.
# - Надежные инструменты: Использует `sgdisk` для надежной неинтерактивной разметки GPT и
#   `cat <<EOF` для предсказуемой генерации файлов конфигурации.
# - Готовность к первой загрузке: Решает "проблему первой загрузки", создавая конфиги
#   на новом разделе extroot И копируя их в работающую систему.
# - Оптимизация для Docker: Предоставляет Docker выделенный раздел ext4 для его root-директории,
#   предотвращая конфликт "overlay on overlay".

# === КОНФИГУРАЦИЯ ===
# Целевое блочное устройство для установки.
DISK="/dev/mmcblk0"
# Размер системного раздела extroot. 4ГБ - щедрый размер для пакетов и конфигов.
EXTROOT_SIZE_GB="4"
# Размер раздела подкачки.
SWAP_SIZE_GB="2"
# Версия скрипта для логирования и отслеживания.
VERSION="2.17"

# Имена разделов определены для ясности и простоты обслуживания.
PART_ROOT="${DISK}p6"
PART_DATA="${DISK}p7"
PART_SWAP="${DISK}p8"
# =====================

# --- Вспомогательные функции ---
fail() { echo -e "\033[0;31m[ERROR] $1\033[0m" >&2; exit 1; }
info() { echo -e "\033[0;32m[INFO] $1\033[0m"; }
# --- Конец вспомогательных функций ---

info "--- Запуск Professional Extroot Script v${VERSION} ---"
info "Целевой диск: ${DISK}"
info "Архитектура: p6 (Extroot, ${EXTROOT_SIZE_GB}GB), p7 (Data), p8 (Swap, ${SWAP_SIZE_GB}GB)"

# === ПРОВЕРКА НА ПОВТОРНЫЙ ЗАПУСК (КРИТИЧНО ДЛЯ UCI-DEFAULTS) ===
CURRENT_OVERLAY_DEV=$(mount | grep 'on /overlay ' | awk '{print $1}')
if [ "$CURRENT_OVERLAY_DEV" = "$PART_ROOT" ]; then
    info "--> Extroot уже активен на ${PART_ROOT}."
    info "--> Скрипт uci-defaults свою задачу выполнил. Завершение работы."
    # Возвращаем 0, чтобы OpenWrt удалил скрипт из /etc/uci-defaults/
    exit 0
fi
# ===============================================================

#
# [ЭТАП 1/5] ПРОВЕРКА ЗАВИСИМОСТЕЙ
#
info "[Этап 1/5] Проверка зависимостей..."
PKGS=""
command -v blkid >/dev/null || PKGS="$PKGS blkid"
if ! opkg list-installed | grep -q block-mount; then PKGS="$PKGS block-mount"; fi
command -v sgdisk >/dev/null || PKGS="$PKGS gptfdisk"
command -v partprobe >/dev/null || PKGS="$PKGS parted"
if ! opkg list-installed | grep -q transmission-daemon; then PKGS="$PKGS transmission-daemon"; fi

if [ -n "$PKGS" ]; then
    info "--> Установка недостающих пакетов: $PKGS"
    opkg update
    opkg install $PKGS || fail "Не удалось установить пакеты."
else
    info "--> Все зависимости на месте."
fi
info "[Этап 1/5] Зависимости в порядке."

#
# [ЭТАП 2/5] РАЗМЕТКА ДИСКА
#
info "[Этап 2/5] Проверка/создание разделов..."
if ! [ -b "$PART_SWAP" ]; then
    info "--> Раздел ${PART_SWAP} не найден. Требуется полная переразметка."
    info "--> НАЧАЛО РАЗМЕТКИ ДИСКА (метод sgdisk)..."
    
    DISK_NAME=${DISK##*/}
    TOTAL_SECTORS=$(cat /sys/class/block/${DISK_NAME}/size)
    SECTOR_SIZE=$(cat /sys/class/block/${DISK_NAME}/queue/hw_sector_size 2>/dev/null || echo 512)
    ROOT_START_SECTOR=1048576
    EXTROOT_SECTORS=$(awk "BEGIN {print int($EXTROOT_SIZE_GB * 1024 * 1024 * 1024 / $SECTOR_SIZE)}")
    ROOT_END_SECTOR=$(awk "BEGIN {print $ROOT_START_SECTOR + $EXTROOT_SECTORS - 1}")
    DATA_START_SECTOR=$(awk "BEGIN {print $ROOT_END_SECTOR + 1}")
    SWAP_SECTORS=$(awk "BEGIN {print int($SWAP_SIZE_GB * 1024 * 1024 * 1024 / $SECTOR_SIZE)}")
    SWAP_START_SECTOR=$(awk "BEGIN {print $TOTAL_SECTORS - $SWAP_SECTORS}")
    DATA_END_SECTOR=$(awk "BEGIN {print $SWAP_START_SECTOR - 1}")
    info "--> Геометрия диска (секторы): p6(${ROOT_START_SECTOR}-${ROOT_END_SECTOR}), p7(${DATA_START_SECTOR}-${DATA_END_SECTOR}), p8(${SWAP_START_SECTOR}-конец)"

    info "--> Удаление старых разделов p6, p7, p8 (если существуют)..."
    sgdisk --delete=8 "$DISK" >/dev/null 2>&1
    sgdisk --delete=7 "$DISK" >/dev/null 2>&1
    sgdisk --delete=6 "$DISK" >/dev/null 2>&1

    info "--> Создание раздела p6 (extroot)..."
    sgdisk --new=6:${ROOT_START_SECTOR}:${ROOT_END_SECTOR} --change-name=6:extroot "$DISK" || fail "Не удалось создать раздел p6"
    info "--> Создание раздела p7 (data)..."
    sgdisk --new=7:${DATA_START_SECTOR}:${DATA_END_SECTOR} --change-name=7:data "$DISK" || fail "Не удалось создать раздел p7"
    info "--> Создание раздела p8 (swap)..."
    sgdisk --new=8:${SWAP_START_SECTOR}:0 --change-name=8:swap --typecode=8:8200 "$DISK" || fail "Не удалось создать раздел p8"
    
    info "--> РАЗМЕТКА ДИСКА ЗАВЕРШЕНА."
    info "--> Обновление таблицы разделов в ядре с помощью partprobe..."
    partprobe "$DISK" || fail "Не удалось обновить таблицу разделов в ядре"
    sleep 3 # Даем ядру время на обработку изменений.
else
    info "--> Разделы уже существуют. Пропускаем разметку."
fi
info "[Этап 2/5] Разделы в порядке."

#
# [ЭТАП 3/5] ПРОВЕРКА И ФОРМАТИРОВАНИЕ ФАЙЛОВЫХ СИСТЕМ
#
info "[Этап 3/5] Проверка/форматирование файловых систем..."
MNT_TEST="/mnt/test_mount"
mkdir -p "$MNT_TEST"

# Проверка и форматирование Extroot (p6)
info "--> Проверка ${PART_ROOT}..."
if ! mount -t ext4 -o ro "$PART_ROOT" "$MNT_TEST" >/dev/null 2>&1; then
    info "--> ${PART_ROOT} не монтируется или поврежден. Принудительное форматирование в ext4..."
    umount "$PART_ROOT" >/dev/null 2>&1 # Страховочный umount против automount
    mkfs.ext4 -F -L extroot "$PART_ROOT" || fail "Ошибка форматирования ext4 для ${PART_ROOT}"
else
    info "--> ${PART_ROOT} в порядке."
    umount "$MNT_TEST"
fi

# Проверка и форматирование Data (p7)
info "--> Проверка ${PART_DATA}..."
if ! mount -t ext4 -o ro "$PART_DATA" "$MNT_TEST" >/dev/null 2>&1; then
    info "--> ${PART_DATA} не монтируется или поврежден. Принудительное форматирование в ext4..."
    umount "$PART_DATA" >/dev/null 2>&1 # Страховочный umount против automount
    mkfs.ext4 -F -L data "$PART_DATA" || fail "Ошибка форматирования ext4 для ${PART_DATA}"
else
    info "--> ${PART_DATA} в порядке."
    umount "$MNT_TEST"
fi

# Проверка и форматирование Swap (p8).
if ! blkid "$PART_SWAP" | grep -q 'TYPE="swap"'; then
    info "--> Создание swap на ${PART_SWAP}..."
    mkswap "$PART_SWAP" || fail "Ошибка создания swap на ${PART_SWAP}"
else
    info "--> Swap раздел ${PART_SWAP} в порядке."
fi

info "--> Очистка временной папки монтирования..."
rm -rf "$MNT_TEST"
info "[Этап 3/5] Файловые системы в порядке."

#
# [ЭТАП 4/5] НАСТРОЙКА СИСТЕМЫ
#
info "[Этап 4/5] Настройка extroot..."
MNT_EXTROOT="/mnt/new_extroot"

for part in "$PART_ROOT" "$PART_DATA" "$PART_SWAP"; do
    i=0; while [ $i -lt 10 ]; do [ -b "$part" ] && break; sleep 1; i=$((i+1)); done
    [ -b "$part" ] || fail "Раздел $part так и не появился."
done

UUID_ROOT=$(blkid -o value -s UUID "$PART_ROOT")
UUID_DATA=$(blkid -o value -s UUID "$PART_DATA")
info "--> UUID Extroot (p6): ${UUID_ROOT}"
info "--> UUID Data (p7):    ${UUID_DATA}"

mkdir -p "$MNT_EXTROOT"
info "--> Монтирование ${PART_ROOT} в ${MNT_EXTROOT}..."
mount "$PART_ROOT" "$MNT_EXTROOT" || fail "Не удалось смонтировать $PART_ROOT"

info "--> Копирование данных из /overlay в ${MNT_EXTROOT}..."
tar -C /overlay -cvf - . | tar -C "$MNT_EXTROOT" -xf -

# === ИСПРАВЛЕНИЕ "ПАПОК-ПРИЗРАКОВ" ===
info "--> Полная очистка системной папки /mnt внутри нового extroot..."
# Чистим именно внутри upper, так как это станет твоим новым корнем после ребута
rm -rf "$MNT_EXTROOT/upper/mnt" && mkdir -p "$MNT_EXTROOT/upper/mnt"
# На всякий случай чистим и корень раздела (вне overlay)
rm -rf "$MNT_EXTROOT/mnt" && mkdir -p "$MNT_EXTROOT/mnt"
# =====================================

    info "--> Генерация fstab на новом extroot..."
    FSTAB_PATH="$MNT_EXTROOT/upper/etc/config/fstab"
    cat > "$FSTAB_PATH" <<EOF
config global
	option anon_swap '0'
	option anon_mount '0'
	option auto_swap '1'
	option auto_mount '1'
	option delay_root '5'
	option check_fs '1'
config mount
	option target '/rom'
	option uuid '3d1747c3-d71d815e-fecac4ae-7494d1e2'
	option enabled '0'
config mount
	option target '/overlay'
	option uuid '$UUID_ROOT'
	option enabled '1'
config mount
	option target '/mnt/data'
	option uuid '$UUID_DATA'
	option enabled '1'
config swap
	option device '$PART_SWAP'
	option enabled '1'
EOF

info "--> Копирование fstab в текущую систему..."
cp -f "$FSTAB_PATH" /etc/config/fstab || fail "Не удалось скопировать fstab"
info "--> Отмонтирование и финальная очистка текущей системы..."
umount -l "$MNT_EXTROOT" 2>/dev/null
rm -rf "$MNT_EXTROOT"
rm -rf "$MNT_TEST"

# Удаляем мусор automount текущей сессии, игнорируя ошибки, если папки заняты
rm -rf /mnt/mmcblk0p* 2>/dev/null
info "--> Текущая система очищена. Подготовка к перезагрузке..."

#
# [ЭТАП 5/5] НАСТРОЙКА ПАПКИ ЗАГРУЗОК И ССЫЛКИ
#
info "[Этап 5/5] Настройка папки загрузок и ссылки /mnt/down..."

# 1. Убеждаемся, что раздел данных смонтирован.
info "[Этап 5/5] Настройка папки загрузок..."
mkdir -p /mnt/data
if ! mount | grep -q 'on /mnt/data'; then
    info "--> /mnt/data не смонтирован, монтирую..."
    mount "$PART_DATA" /mnt/data || fail "Не удалось смонтировать /mnt/data"
fi

# 2. Создаем целевые директории на разделе данных.
mkdir -p /mnt/data/docker
mkdir -p /mnt/data/downloads

# 3. Настраиваем права для Transmission на ЦЕЛЕВОЙ директории.
info "--> Настройка прав для /mnt/data/downloads..."
chown -R transmission:transmission /mnt/data/downloads
chmod -R g+rw /mnt/data/downloads

# 4. Принудительно создаем симлинк и чистим хвосты automount.
info "--> Принудительное создание симлинка /mnt/down..."
rm -rf /mnt/down
# Убираем папку, которую мог создать automount вместо нашего раздела
[ -d "/mnt/mmcblk0p7" ] && rm -rf /mnt/mmcblk0p7 
ln -sfn /mnt/data/downloads /mnt/down

info "[Этап 5/5] Настройка папки загрузок завершена."

# Отправляем команду перезагрузки в фон, чтобы скрипт успел вернуть код 0
# и система могла корректно удалить его из /etc/uci-defaults/
info "--- Скрипт настройки Extroot v${VERSION} завершил работу. ---"
info "--- Требуется перезагрузка для применения всех изменений. 3s ---"
(sleep 3 && reboot) &
exit 0