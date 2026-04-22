cat << 'EOF' > /opt/root/top_conn.sh
#!/bin/sh

# === НАСТРОЙКИ ===
INTERVAL=3  # Интервал обновления в секундах
# =================

# 1. Проверка и установка watch
if ! command -v watch >/dev/null 2>&1; then
    echo "Utility 'watch' not found. Installing procps-ng-watch..."
    opkg update && opkg install procps-ng-watch
    if [ $? -ne 0 ]; then
        echo "Error: Could not install watch. Check internet connection."
        exit 1
    fi
fi

# 2. Механизм авто-запуска в режиме watch
# Если скрипт запущен без аргумента "run", он перезапускает сам себя через watch
if [ "$1" != "run" ]; then
    watch -t -n $INTERVAL "$0 run"
    exit
fi

# 3. ОСНОВНАЯ ЛОГИКА (выполняется внутри watch)

# Сбор базы имен из hotspot
NAME_DB=$(ndmc -c "show ip hotspot" | awk '
    $1 == "mac:" {m=$2} 
    $1 == "hostname:" {h=$2} 
    $1 == "name:" {
        n=$2; 
        final_n = (n != "") ? n : h;
        if(m != "" && final_n != "") print m, final_n;
        m=""; h=""; n="";
    }
' | sort -u)

# Сбор статистики соединений
CONN_DATA=$(awk '
NR==FNR { if(NR>1) macs[$1] = $4; next }
{
    if(match($0, /src=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)) {
        ip = substr($0, RSTART+4, RLENGTH-4)
        count[ip]++
    }
}
END {
    for (ip in count) {
        m = (macs[ip] != "") ? macs[ip] : "-"
        print count[ip], ip, m
    }
}' /proc/net/arp /proc/net/nf_conntrack | sort -nr -k1 | head -n 15)

# Вывод таблицы
printf "Top Clients by Connections (Every %ss)\n" "$INTERVAL"
printf "%-7s | %-15s | %-17s | %s\n" "CONNS" "IP ADDRESS" "MAC ADDRESS" "HOSTNAME"
printf -- "----------------------------------------------------------------------\n"

echo "$CONN_DATA" | while read -r cnt ip mac; do
    hostname=""
    if [ "$mac" != "-" ]; then
        hostname=$(echo "$NAME_DB" | grep -i "^$mac " | awk '{print $2}' | head -n 1)
    fi

    if [ -z "$hostname" ]; then
        case "$ip" in
            127.0.0.1) hostname="localhost" ;;
            192.168.0.1|192.168.1.1|192.168.2.1) hostname="Keenetic" ;;
            100.*)     hostname="Provider_NAT" ;;
            *)         hostname="Internet" ;;
        esac
    fi

    printf "%-7s | %-15s | %-17s | %s\n" "$cnt" "$ip" "$mac" "$hostname"
done
EOF

chmod +x /opt/root/top_conn.sh