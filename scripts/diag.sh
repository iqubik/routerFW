#!/bin/sh
# прямое выполнение на роутере: wget -qO- https://raw.githubusercontent.com/iqubik/routerFW/main/scripts/diag.sh | sh
# ==============================================================================
#  OpenWrt Universal Diagnostic Tool
#  Version: v1.7 (Audited Edition)
#  Description: Generates a comprehensive system health report in Markdown.
#               Designed for debugging network, wireless, and routing issues.
#               Automatically sanitizes passwords, keys, and sensitive data.
# ==============================================================================
#
#  TABLE OF CONTENTS:
#  1. SYSTEM & HARDWARE ....... Board info, Uptime, Load averages, RAM, Storage
#  2. INTERFACES (L1/L2) ...... Link speed/duplex, DSA/VLAN config, Port errors
#  3. ROUTING & CONNECTIVITY .. Routing table, ARP, Ping/DNS/HTTP checks, VPN rules
#  4. FIREWALL & TRAFFIC ...... Flow Offloading (HW/SW), Conntrack, NFT counters
#  5. PROCESSES & PACKAGES .... Installed packages, Service status, Top CPU consumers
#  6. WIRELESS HEALTH ......... Signal stats, Channel utilization (Survey), Mesh info
#  7. CONFIGURATION ........... Sanitized UCI exports (network, wireless, firewall, etc.)
#  8. LOGS .................... Critical Kernel errors (dmesg) and System logs
#
# ==============================================================================

# === CONFIG ===
[ -f /proc/sys/kernel/hostname ] && HOST=$(cat /proc/sys/kernel/hostname) || HOST="OpenWrt"
LOG="/tmp/diag_${HOST}.md"
echo "# Diagnostic Report: $HOST (v7 - Audited Edition)" > "$LOG"
echo "Date: $(date)" >> "$LOG"

# === HELPERS ===
header() { echo -e "\n## $1" >> "$LOG"; echo '```' >> "$LOG"; }
footer() { echo '```' >> "$LOG"; }
run() { echo -e "\n> $1" >> "$LOG"; eval "$1" >> "$LOG" 2>&1; }

# === 1. SYSTEM & HARDWARE ===
header "1. SYSTEM RESOURCES"
run "ubus call system board"
run "uptime"
run "cat /proc/loadavg"
run "free -m"
echo -e "\n> Memory Details:" >> "$LOG"
grep -E 'Slab|Active|Inactive|Dirty|Mapped' /proc/meminfo >> "$LOG"

echo -e "\n> Storage:" >> "$LOG"
df -hT | grep -v "tmpfs" >> "$LOG"
footer

# === 2. INTERFACES (L1/L2) ===
header "2. PHYSICAL & SWITCH STATUS"

# 1. Sysfs Speed Check (Works without ethtool on DSA)
echo "> Physical Link Status (Sysfs):" >> "$LOG"
# Improved filter to exclude wireless interfaces from this section
for iface in $(ls /sys/class/net/ | grep -vE "lo|br-|mon|bat|wlan|sit|gre|wwan|phy|ap[0-9]|mesh"); do
    OPERSTATE=$(cat /sys/class/net/$iface/operstate 2>/dev/null)
    if [ "$OPERSTATE" = "up" ]; then
        SPEED=$(cat /sys/class/net/$iface/speed 2>/dev/null || echo "?")
        DUPLEX=$(cat /sys/class/net/$iface/duplex 2>/dev/null || echo "?")
        echo "$iface: UP | Speed: ${SPEED}Mbps | Duplex: $DUPLEX" >> "$LOG"
    elif [ "$OPERSTATE" = "down" ]; then
        # Uncomment to see down interfaces
        # echo "$iface: DOWN" >> "$LOG"
        :
    fi
done

# 2. DSA / VLAN Status (CRITICAL FOR NEW OPENWRT)
if command -v bridge >/dev/null; then
    echo -e "\n> Bridge VLANs (DSA Config):" >> "$LOG"
    bridge vlan show 2>/dev/null >> "$LOG"
fi

# 3. Errors check (Universal)
echo -e "\n> Interface Errors:" >> "$LOG"
if command -v ethtool >/dev/null; then
    for iface in $(ls /sys/class/net/ | grep -vE "lo|br-|mon|bat|wlan|sit|gre"); do
        ERR=$(ethtool -S "$iface" 2>/dev/null | grep -E 'drop|error|crc|fail' | grep -v ': 0')
        [ -n "$ERR" ] && echo "--- $iface ---" >> "$LOG" && echo "$ERR" >> "$LOG"
    done
else
    # Fallback to standard RX/TX counters
    grep . /sys/class/net/*/statistics/{rx,tx}_errors 2>/dev/null | grep -v ":0" >> "$LOG"
    grep . /sys/class/net/*/statistics/{rx,tx}_dropped 2>/dev/null | grep -v ":0" >> "$LOG"
fi
footer

# === 3. ROUTING & CONNECTIVITY ===
header "3. ROUTING & CONNECTIVITY"
run "ip route"
echo -e "\n> Policy Routing (Zapret/VPN check):" >> "$LOG"
ip rule list >> "$LOG"

# ARP
LAN_IF=$(ip -4 route show | grep '192.168' | grep -v 'reserve' | awk '{print $3}' | head -n 1)
echo -e "\n> Neighbors (ARP):" >> "$LOG"
if command -v arp-scan >/dev/null && [ -n "$LAN_IF" ]; then
    arp-scan -I "$LAN_IF" --localnet --ignoredups --retry=1 2>/dev/null >> "$LOG"
else
    ip neigh show | head -n 30 >> "$LOG"
fi

# Fixed Connectivity Check (Split DNS & HTTP)
echo -e "\n> Connectivity Check:" >> "$LOG"

# 1. IP Check
if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    echo "1. IP Ping (1.1.1.1): OK" >> "$LOG"
else
    echo "1. IP Ping (1.1.1.1): FAIL" >> "$LOG"
fi

# 2. DNS Check (Always run)
echo "--- DNS Check (google.com) ---" >> "$LOG"
if nslookup google.com >/dev/null 2>&1; then
    echo "DNS Resolution: OK" >> "$LOG"
    nslookup google.com 2>&1 | tail -n 5 >> "$LOG"
else
    echo "DNS Resolution: FAIL" >> "$LOG"
    nslookup google.com 2>&1 >> "$LOG"
fi

# 3. HTTP/Application Check
echo "--- HTTP Check ---" >> "$LOG"
if command -v curl >/dev/null; then
    # Добавил флаг -4, чтобы исключить проблемы IPv6
    # Сменил google.com на 1.1.1.1 (Cloudflare), так как Google часто ломается из-за Zapret
    HTTP_CODE=$(curl -4 -sS -I -m 5 -o /dev/null -w "%{http_code}" https://1.1.1.1 2>&1)
    
    # Проверка на успешные коды (200, 301, 302)
    case "$HTTP_CODE" in
        200|301|302)
            echo "HTTP Connection: OK (Code: $HTTP_CODE)" >> "$LOG"
            ;;
        *)
            # Если в переменную попала ошибка curl (текст), она выведется тут
            echo "HTTP Connection: FAIL (Result: $HTTP_CODE)" >> "$LOG"
            # Повторный тест с выводом деталей для отладки
            echo "DEBUG: Trying verbose connection to google.com..." >> "$LOG"
            curl -4 -I -m 5 -v https://google.com 2>&1 | grep "curl:" >> "$LOG"
            ;;
    esac
else
    echo "curl not found, skipping HTTP check" >> "$LOG"
fi
footer

# === 4. FIREWALL & TRAFFIC ===
header "4. FIREWALL & TRAFFIC"

# Configuration vs Reality Check
FLOW_CONF=$(uci get firewall.defaults.flow_offloading 2>/dev/null)
echo "> Flow Offloading Config: ${FLOW_CONF:-Disabled/Unknown}" >> "$LOG"

echo "> Offloading Reality Check:" >> "$LOG"
if [ -d /sys/module/xt_flowoffload ]; then
    REF=$(cat /sys/module/xt_flowoffload/refcnt 2>/dev/null)
    echo "Software Offload Module (xt_flowoffload): LOADED (Refcount: $REF)" >> "$LOG"
else
    echo "Software Offload Module (xt_flowoffload): NOT LOADED" >> "$LOG"
fi
if command -v ethtool >/dev/null; then
    # Check HW offload on WAN/LAN if possible (assuming eth0 for simplicity, script adapts)
    echo "HW Offload flags (eth0 sample):" >> "$LOG"
    ethtool -k eth0 2>/dev/null | grep "flow-offload" >> "$LOG"
fi

echo -e "\n> Conntrack:" >> "$LOG"
if [ -f /proc/sys/net/netfilter/nf_conntrack_count ]; then
    echo "$(cat /proc/sys/net/netfilter/nf_conntrack_count) / $(cat /proc/sys/net/netfilter/nf_conntrack_max)" >> "$LOG"
elif [ -f /proc/net/nf_conntrack_count ]; then
    echo "$(cat /proc/net/nf_conntrack_count) / $(cat /proc/sys/net/netfilter/nf_conntrack_max)" >> "$LOG"
else
    echo "N/A" >> "$LOG"
fi

echo -e "\n> NFT Traffic Counters (Top 20 Rules):" >> "$LOG"
if command -v nft >/dev/null; then
    nft list ruleset | grep "packets" | sort -k4 -n -r | head -n 20 >> "$LOG"
fi
footer

# === 5. PROCESSES & PACKAGES ===
header "5. SOFTWARE & PROCESSES"
echo "> Installed Key Packages:" >> "$LOG"
opkg list-installed | grep -E "kmod-mt76|hostapd|zapret|dnsmasq|firewall|wireguard|openvpn|batman|usteer|ethtool" >> "$LOG"

echo -e "\n> Service Status:" >> "$LOG"
for svc in firewall dnsmasq usteer zapret network uhttpd; do
    if [ -f "/etc/init.d/$svc" ]; then
        # Печатаем имя сервиса + пробел, затем статус, всё в одну строку или через двоеточие
        echo -n "$svc: " >> "$LOG"
        /etc/init.d/$svc status 2>/dev/null >> "$LOG" || echo "NOT RUNNING" >> "$LOG"
    else
        echo "$svc: NOT INSTALLED" >> "$LOG"
    fi
done

echo -e "\n> Targeted Processes:" >> "$LOG"
ps -w | grep -E "zapret|nfqws|tpws|openvpn|wireguard|transmission|usteer|batman" | grep -v grep >> "$LOG"

echo -e "\n> CPU Hogs:" >> "$LOG"
top -b -n 1 | head -n 15 >> "$LOG"
footer

# === 6. WIRELESS HEALTH ===
header "6. WIFI & MESH HEALTH"
run "iwinfo"

echo -e "\n> Channel Utilization (Survey Dump):" >> "$LOG"
for dev in $(iw dev | grep Interface | awk '{print $2}'); do
    iw dev $dev survey dump | awk -v dev="$dev" '
        BEGIN { best_active=0; found=0; best_noise="N/A" }
        /frequency:/ { 
            if (cur_active > 0 && cur_in_use) {
                if (cur_active > best_active) {
                    best_active = cur_active; best_freq = cur_freq; best_noise = cur_noise
                    best_load = (cur_busy / cur_active) * 100
                    best_tx = (cur_tx / cur_active) * 100
                    best_rx = (cur_rx / cur_active) * 100
                    found = 1
                }
            }
            cur_freq=$2; cur_in_use=($0 ~ /in use/); cur_active=0; cur_busy=0; cur_tx=0; cur_rx=0
            cur_noise="N/A"
        }
        /noise:/ { cur_noise=$2 }
        /active time:/ { cur_active=$4 }
        /busy time:/ { cur_busy=$4 }
        /transmit time:/ { cur_tx=$4 }
        /receive time:/ { cur_rx=$4 }
        END {
            if (found) {
                printf "--- %s ---\n", dev
                printf "  Freq: %s MHz | Noise: %s dBm\n", best_freq, best_noise
                printf "  Load: %.1f%% (Busyness)\n", best_load
                printf "  TX:   %.1f%% | RX: %.1f%%\n", best_tx, best_rx
            }
        }
    ' >> "$LOG"
done

# Batman / Usteer
if command -v batctl >/dev/null; then
    run "batctl n"
    run "batctl tg | head -n 15"
fi
if command -v ubus >/dev/null; then
    echo -e "\n> Usteer Info:" >> "$LOG"
    ubus call usteer local_info 2>/dev/null >> "$LOG"
    ubus call usteer get_clients 2>/dev/null >> "$LOG"
fi
footer

# === 7. CONFIGURATION (Sanitized) ===
header "7. CONFIGURATION"
for cfg in network wireless firewall dhcp usteer batman-adv; do
    [ -f "/etc/config/$cfg" ] || continue
    echo "--- $cfg ---" >> "$LOG"
    # Добавил private_key и preshared_key в фильтр
    uci export "$cfg" 2>/dev/null | sed -E "s/(option|list) (key|password|secret|psk|users|auth_secret|private_key|preshared_key) (.+)/\1 \2 '[HIDDEN]'/" >> "$LOG"
done
footer

# === 8. LOGS ===
header "8. CRITICAL LOGS"
echo "--- Kernel (Errors/Warns) ---" >> "$LOG"
dmesg | grep -iE 'error|fail|warn|oom|panic|throttle' | tail -n 40 >> "$LOG"
echo -e "\n--- System Events (Filtered) ---" >> "$LOG"
# Filter out "promiscuous mode" spam caused by this script itself
logread | grep -vE "BEACON-REQ|BEACON-RESP|BSS-TM-RESP|promiscuous mode|udhcpc: sending renew" | tail -n 60 >> "$LOG"
footer

echo "Done. Report: $LOG"
pause
echo "========================================================================================="
cat "/tmp/diag_${HOST}.md"