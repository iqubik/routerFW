#!/bin/sh

# === НАСТРОЙКИ ===
INTERVAL=3  # Интервал обновления в секундах
# =================

if ! command -v watch >/dev/null 2>&1; then
    echo "Utility 'watch' not found. Installing procps-ng-watch..."
    opkg update && opkg install procps-ng-watch || exit 1
fi

if [ "$1" != "run" ]; then
    watch -t -n $INTERVAL "$0 run"
    exit
fi

HOTSPOT=$(ndmc -c "show ip hotspot")

printf "Top Clients by Connections (Every %ss)\n" "$INTERVAL"
printf "%-7s | %-15s | %-17s | %s\n" "CONNS" "IP ADDRESS" "MAC ADDRESS" "HOSTNAME"
printf -- "----------------------------------------------------------------------\n"

echo "$HOTSPOT" | awk -v arp_file="/proc/net/arp" -v conn_file="/proc/net/nf_conntrack" '
BEGIN {
    while ((getline < arp_file) > 0) {
        if ($1 ~ /^[0-9]+\./ && $4 != "00:00:00:00:00:00") {
            ip_mac[$1] = tolower($4)
        }
    }
    close(arp_file)

    while ((getline < conn_file) > 0) {
        if (match($0, /src=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)) {
            ip = substr($0, RSTART+4, RLENGTH-4)
            ip_conns[ip]++
        }
    }
    close(conn_file)
}

{
    sub(/\r$/, "", $0) # Очистка от скрытых символов возврата каретки
    
    if ($1 == "mac:") {
        cur_mac = tolower($2)
    } else if ($1 == "interface:") {
        cur_mac = ""
    } else if ($1 == "hostname:" && cur_mac != "") {
        $1 = ""
        sub(/^ +/, "", $0)
        # Сохраняем имя, только если оно не пустое и не равно дефису
        if ($0 != "" && $0 != "-") host[cur_mac] = $0
    } else if ($1 == "name:" && cur_mac != "") {
        $1 = ""
        sub(/^ +/, "", $0)
        if ($0 != "" && $0 != "-") name[cur_mac] = $0
    }
}

END {
    for (m in host) mac_name[m] = (name[m] != "") ? name[m] : host[m]
    for (m in name) if (mac_name[m] == "") mac_name[m] = name[m]

    for (ip in ip_conns) {
        count = ip_conns[ip]
        mac = (ip_mac[ip] != "") ? ip_mac[ip] : "-"
        hname = ""

        if (mac != "-") hname = mac_name[mac]

        # Дополнительная страховка: если имя пустое или всё-таки проскочил дефис
        if (hname == "" || hname == "-") {
            if (ip == "127.0.0.1") {
                hname = "localhost (Router)"
            } else if (ip ~ /^192\.168\./) {
                if (ip ~ /\.1$/) hname = "Keenetic (Router LAN)"
                else hname = "-"
            } else if (ip ~ /^10\./) {
                hname = "VPN_Interface (Router)"
            } else if (ip ~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./) {
                if (ip ~ /\.1$/) hname = "Private_Subnet (Router)"
                else hname = "Private_Subnet_Device"
            } else if (ip ~ /^100\./) {
                hname = "Provider_NAT_WAN (Router)"
            } else {
                hname = "Internet / External"
            }
        }

        printf "%06d|%-7s | %-15s | %-17s | %s\n", count, count, ip, mac, hname
    }
}' | sort -nr | head -n 15 | cut -d'|' -f2-
