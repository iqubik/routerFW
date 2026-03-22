#!/bin/bash

# Имя файла со списком доменов
INPUT_FILE="tocheck.txt"

# Куда сохраняем результаты
GOOD_FILE="good_snis.txt"
BAD_FILE="bad_snis.txt"

# Проверяем, существует ли файл со списком
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Файл $INPUT_FILE не найден!"
    echo "Создайте его и добавьте домены (по одному на строку)."
    exit 1
fi

# Очищаем файлы с результатами от предыдущих проверок
> "$GOOD_FILE"
> "$BAD_FILE"

echo "🔍 Начинаем проверку доменов из $INPUT_FILE..."
echo "=================================================="

# Читаем файл построчно, предварительно удаляя виндовые возвраты каретки (\r)
while IFS= read -r domain || [ -n "$domain" ]; do
    # Пропускаем пустые строки
    if [ -z "$domain" ]; then
        continue
    fi

    # Убираем лишние пробелы в начале и конце
    domain=$(echo "$domain" | xargs)

    # Добавляем https://, если пользователь забыл его указать
    if [[ ! "$domain" =~ ^https?:// ]]; then
        url="https://$domain"
    else
        url="$domain"
    fi

    # Выполняем наш "источник правды"
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 --tlsv1.3 "$url")

    # Анализируем ответ
    if [ "$http_code" = "000" ]; then
        # Красный цвет для плохих
        echo -e "[\e[31mВ МУСОР\e[0m] $domain (Код: $http_code)"
        echo "$domain" >> "$BAD_FILE"
    else
        # Зеленый цвет для хороших
        echo -e "[\e[32mГОДИТСЯ\e[0m] $domain (Код: $http_code)"
        echo "$domain" >> "$GOOD_FILE"
    fi

done < <(tr -d '\r' < "$INPUT_FILE")

echo "=================================================="
echo "✅ Проверка завершена!"
echo "📁 Подходящие домены сохранены в: $GOOD_FILE"
echo "🗑️ Неподходящие домены сохранены в: $BAD_FILE"
