#!/bin/sh

# === НАСТРОЙКИ ===
INTERVAL=3                   # Интервал обновления (сек)
CACHE_TTL=60                 # Как часто дергать ndmc (сек)
CACHE_FILE="/tmp/hotspot_cache.txt"
# =================

C_CYAN='\033[1;36m'
C_GRAY='\033[90m'            # Добавлен серый цвет
C_RESET='\033[0m'

clear_screen() {
    printf "\033[H\033[J"
}

while true; do
    CURRENT_TIME=$(date +%s)
    
    # АТОМАРНОЕ ОБНОВЛЕНИЕ КЭША
    if [ ! -f "$CACHE_FILE" ]; then
        ndmc -c "show ip hotspot" > "${CACHE_FILE}.tmp" 2>/dev/null && mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
    else
        FILE_MOD_TIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE")
        AGE=$((CURRENT_TIME - FILE_MOD_TIME))
        if [ "$AGE" -ge "$CACHE_TTL" ]; then
            ( ndmc -c "show ip hotspot" > "${CACHE_FILE}.tmp" 2>/dev/null && mv "${CACHE_FILE}.tmp" "$CACHE_FILE" ) &
        fi
    fi

    clear_screen
    printf "${C_CYAN}========================================================================================================${C_RESET}\n"
    printf " %-22s | %-15s | %-17s | %-6s (%-3s / %-3s) | %-10s\n" "HOSTNAME" "IP ADDRESS" "MAC ADDRESS" "CONNS" "TCP" "UDP" "SESS VOL"
    printf "${C_CYAN}========================================================================================================${C_RESET}\n"

    # Передаем цвета в awk через переменные -v
    awk -v arp_file="/proc/net/arp" -v conn_file="/proc/net/nf_conntrack" -v cache_file="$CACHE_FILE" -v c_gray="$C_GRAY" -v c_reset="$C_RESET" '
    function format_bytes(b) {
        if (b < 1024) return b " B"
        b /= 1024; if (b < 1024) return sprintf("%.1f KB", b)
        b /= 1024; if (b < 1024) return sprintf("%.1f MB", b)
        b /= 1024; return sprintf("%.2f GB", b)
    }

    BEGIN {
        # 1. Загрузка ARP таблицы
        while ((getline < arp_file) > 0) {
            if ($1 ~ /^[0-9]+\./ && $4 ~ /^[0-9a-fA-F:]+$/ && $4 != "00:00:00:00:00:00") {
                ip_mac[$1] = tolower($4)
            }
        }
        close(arp_file)

        # 2. Безопасный парсинг кэша ndmc
        while ((getline < cache_file) > 0) {
            sub(/\r$/, "")
            line = $0
            sub(/^[ \t]+/, "", line)
            if (line == "") continue;
            
            idx = index(line, ":")
            if (idx == 0) continue;
            
            key = substr(line, 1, idx - 1)
            val = substr(line, idx + 1)
            sub(/^[ \t]+/, "", val)

            if (key == "mac" && length(val) >= 17) {
                cur_mac = tolower(substr(val, 1, 17))
            } else if (key == "interface") {
                cur_mac = ""
            } else if (key == "hostname" && cur_mac != "" && val != "" && val != "-") {
                host[cur_mac] = val
            } else if (key == "name" && cur_mac != "" && val != "" && val != "-") {
                name[cur_mac] = val
            }
        }
        close(cache_file)
        
        # 3. Парсинг соединений
        while ((getline < conn_file) > 0) {
            if ($1 != "ipv4") continue;
            
            ip = ""; proto = $3; bytes = 0;
            
            for(i=4; i<=NF; i++) {
                if (substr($i, 1, 4) == "src=") {
                    if (ip == "") ip = substr($i, 5)
                }
                if (substr($i, 1, 6) == "bytes=") {
                    bytes += substr($i, 7)
                }
            }
            
            if (ip != "") {
                ip_conns[ip]++
                ip_bytes[ip] += bytes
                if (proto == "tcp") ip_tcp[ip]++
                else if (proto == "udp") ip_udp[ip]++
            }
        }
        close(conn_file)
        
        # 4. Сборка имен
        for (m in host) mac_name[m] = host[m]
        for (m in name) mac_name[m] = name[m] 

        # 5. Вывод
        for (ip in ip_conns) {
            count = ip_conns[ip]
            tcp_c = ip_tcp[ip] + 0
            udp_c = ip_udp[ip] + 0
            bytes_total = ip_bytes[ip] + 0
            
            mac = (ip_mac[ip] != "") ? ip_mac[ip] : "-"
            hname = ""
            is_gray = 0 # Флаг для определения, нужно ли красить строку в серый

            if (mac != "-") hname = mac_name[mac]

            # Умные дефолтные имена, если хостнейм не найден
            if (hname == "" || hname == "-") {
                is_gray = 1 # Включаем серый цвет
                
                if (ip == "127.0.0.1") hname = "(localhost)"
                else if (ip ~ /\.1$/ && (ip ~ /^192\.168\./ || ip ~ /^10\./ || ip ~ /^172\./)) hname = "(Router_LAN)"
                else if (ip ~ /^10\.8\./) hname = "(VPN_Interface)"
                else if (ip ~ /^192\.168\./ || ip ~ /^10\./ || ip ~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./) hname = "(LAN_Device)"
                else if (ip ~ /^100\./) hname = "(NAT_WAN)"
                else hname = "Internet / External"
            }
            
            # Применяем цвет
            color = is_gray ? c_gray : ""
            
            # Вставляем color в начале строки и c_reset в самом конце
            printf "%06d|%s %-22.22s | %-15s | %-17s | %-6s (%-3s / %-3s) | %-10s%s\n", 
                count, color, hname, ip, mac, count, tcp_c, udp_c, format_bytes(bytes_total), c_reset
        }
    }' | sort -nr | head -n 15 | cut -d'|' -f2-

    printf "${C_CYAN}========================================================================================================${C_RESET}\n"
    printf "Обновление: каждые %d сек. (Ctrl+C для выхода). Кэш имён обновляется раз в %d сек.\n" "$INTERVAL" "$CACHE_TTL"
    sleep "$INTERVAL"
done