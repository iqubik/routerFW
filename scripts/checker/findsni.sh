#!/bin/bash
VERSION="0.2"
AUTHOR="iqubik"
REPO="https://github.com/iqubik/routerFW/tree/main/scripts/checker"

chmod +x RealiTLScanner-linux-64

if [ -z "$1" ]; then
    echo "findsni.sh v$VERSION"
    echo "Автор: $AUTHOR"
    echo "Репозиторий: $REPO"
    echo "Linux Утилита для автоматического поиска и проверки корректных SNI для вашего домена."
    echo "Использование: $0 <IP-адрес вашего хоста>"
    echo "Результат работы будет записан в good_snis.txt"
    exit 1
fi

TARGET_IP="$1"
SCAN_TIME=120

> tocheck.txt
rm -f good_snis.txt unstable_snis.txt bad_snis.txt

echo "Запуск сканера findsni.sh v.$VERSION для $TARGET_IP на $SCAN_TIME секунд..."
echo "======================================================================"

# Запускаем конвейер в фоне
./RealiTLScanner-linux-64 --addr "$TARGET_IP" \
    | grep --line-buffered -oP 'cert-domain=\K\S+' \
    | sed -u 's/^\*\.//' \
    | awk '!seen[$0]++ {print; fflush()}' > tocheck.txt &

LAST_LINE=0

# Цикл таймера
for (( i=$SCAN_TIME; i>0; i-- )); do
    CURRENT_LINE=$(wc -l < tocheck.txt 2>/dev/null || echo 0)
    
    # Если появились новые домены
    if [ "$CURRENT_LINE" -gt "$LAST_LINE" ]; then
        # Очищаем строку с таймером, чтобы вывод не поехал
        echo -ne "\033[2K\r"
        # Выводим только новые строки
        tail -n +$((LAST_LINE + 1)) tocheck.txt
        LAST_LINE=$CURRENT_LINE
    fi
    
    # Печатаем обновленный таймер
    echo -ne "⏳ Осталось: $i сек. | Найдено: $LAST_LINE \r"
    sleep 1
done

echo -e "\n🛑 Время вышло! Останавливаем сканер..."
pkill -f "RealiTLScanner-linux-64 --addr $TARGET_IP" 2>/dev/null

echo "✅ Сбор завершен. Запуск checker.py..."
echo "======================================================================"
python3 -B checker.py

if [ -s "good_snis.txt" ]; then
    echo "📋 Идеальные домены:"
    cat good_snis.txt
fi
