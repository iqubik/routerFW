#!/bin/sh
echo "====== Packager list v0.2 iqubik ======"
# Проверяем, передан ли аргумент (путь к файлу)
if [ -z "$1" ]; then
    # --- Режим без аргументов (по умолчанию) ---
    INPUT_FILE="/usr/lib/opkg/status"
    # Куда кладем результаты
    OUT_FULL="/etc/config/status"
    OUT_LITE="/etc/config/status_lite"
else
    # --- Режим с аргументом ---
    INPUT_FILE="$1"
    
    # Проверка существования файла
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Ошибка: Файл $INPUT_FILE не найден."
        exit 1
    fi

    # Получаем путь к папке, где лежит файл
    WORK_DIR=$(dirname "$INPUT_FILE")
    
    # Формируем пути для вывода в ту же папку
    # Используем имя status_filtered, чтобы не перезатереть исходник, если он называется status
    OUT_FULL="${WORK_DIR}/status_filtered"
    OUT_LITE="${WORK_DIR}/status_lite"
fi

# 1. Формируем фильтрованный полный список установленных пакетов
# (Убрал cat, так как awk умеет читать файлы напрямую - это быстрее и правильнее)
awk -v RS="" -v ORS="\n\n" '!/Auto-Installed: yes/' "$INPUT_FILE" > "$OUT_FULL"
echo "Выводим полный в $OUT_FULL"

# 2. Формируем краткий список
awk -v RS="" '!/Auto-Installed: yes/ {print $2}' "$INPUT_FILE" > "$OUT_LITE"
echo "Выводим краткий в $OUT_LITE"