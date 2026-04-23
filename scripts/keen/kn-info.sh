#!/bin/sh

# Цвета
C_RESET='\033[0m'
C_GREEN='\033[1;32m'
C_CYAN='\033[1;36m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_WHITE='\033[1;37m'

# Файл данных
JSON_FILE="/tmp/ver.json"
curl -s http://localhost:79/rci/show/version > "$JSON_FILE"

# Функция парсинга
get_json_val() {
    grep -o "\"$1\": *\"[^\"]*\"" "$JSON_FILE" | head -1 | cut -d'"' -f4
}

# --- 1. СБОР ОСНОВНЫХ ДАННЫХ ---
MODEL_RAW=$(get_json_val "model")
ARCH=$(get_json_val "arch")
RELEASE=$(get_json_val "release")
TITLE=$(get_json_val "title")
SANDBOX=$(get_json_val "sandbox")
HW_ID=$(get_json_val "hw_id")
REGION=$(get_json_val "region")
BUILD_DATE=$(grep -A 4 '"ndm":' "$JSON_FILE" | grep '"cdate":' | cut -d'"' -f4)

# Читаем компоненты для анализа
COMPONENTS=$(grep '"components":' "$JSON_FILE")
FEATURES=$(grep '"features":' "$JSON_FILE")

# --- 2. ОПРЕДЕЛЕНИЕ ВЕНДОРА И ПОРТА ---
PORT_FLAG=""
VENDOR_DETECTED=""

case "$MODEL_RAW" in
  *Cudy*|*WBR3000*|*TR3000*|*WR3000*)     VENDOR_DETECTED="Cudy";     PORT_FLAG="[Port]" ;;
  *CMCC*|*RAX3000M*)                      VENDOR_DETECTED="CMCC";     PORT_FLAG=" [Port]" ;;
  *Netis*|*NX31*|*NX32*|*N6*)             VENDOR_DETECTED="Netis";    PORT_FLAG=" [Port]" ;;
  *Redmi*)                                VENDOR_DETECTED="Redmi";    PORT_FLAG=" [Port]" ;;
  *Xiaomi*|*AX3000T*|*3G*|*3P*|*4A*|*4C*) VENDOR_DETECTED="Xiaomi";   PORT_FLAG=" [Port]" ;;
  *Mercusys*)                             VENDOR_DETECTED="Mercusys"; PORT_FLAG=" [Port]" ;;
  *SmartBox*)                             VENDOR_DETECTED="SmartBox"; PORT_FLAG=" [Port]" ;;
  *TP-Link*|*EC330*|*Archer*)             VENDOR_DETECTED="TP-Link";  PORT_FLAG=" [Port]" ;;
  *Linksys*)                              VENDOR_DETECTED="Linksys";  PORT_FLAG=" [Port]" ;;
  *WiFire*)                               VENDOR_DETECTED="WiFire";   PORT_FLAG=" [Port]" ;;
  *Vertell*)                              VENDOR_DETECTED="Vertell";  PORT_FLAG=" [Port]" ;;
  *MTS*|*WG430*)                          VENDOR_DETECTED="MTS";      PORT_FLAG=" [Port]" ;;
  *HLK*)                                  VENDOR_DETECTED="HLK";      PORT_FLAG=" [Port]" ;;
  *Keenetic*)                             VENDOR_DETECTED="Keenetic";;
  *)                                      VENDOR_DETECTED="Keenetic";;
esac

# Формирование имени
if [ -n "$VENDOR_DETECTED" ] && [ "$VENDOR_DETECTED" != "Keenetic" ]; then
    case "$MODEL_RAW" in
        *"$VENDOR_DETECTED"*) MODEL_DISPLAY="$MODEL_RAW" ;;
        *) MODEL_DISPLAY="$VENDOR_DETECTED $MODEL_RAW" ;;
    esac
else
    MODEL_DISPLAY="$MODEL_RAW"
fi

# --- 3. ИНТЕГРАЦИЯ ДАННЫХ ИЗ KEENKIT ---

# 3.1. Температуры и точная модель процессора
get_radio_temp() {
    curl -s http://localhost:79/rci/show/interface | awk -v iface="$1" '
      !in_iface {
        pos = index($0, "\"" iface "\"")
        if (pos) { in_iface = 1; $0 = substr($0, pos) }
      }
      in_iface && match($0, /"temperature": *[0-9]+/) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
      in_iface && /}/ { in_iface=0 }
    ' | grep -o '[0-9]*' | head -n1
}

# Функция для многоцветной раскраски температуры
color_temp() {
    local t=$1
    if [ "$t" -lt 55 ]; then
        printf "%s%s°C%s" "$C_CYAN" "$t" "$C_RESET"
    elif [ "$t" -lt 70 ]; then
        printf "%s%s°C%s" "$C_GREEN" "$t" "$C_RESET"
    elif [ "$t" -lt 85 ]; then
        printf "%s%s°C%s" "$C_YELLOW" "$t" "$C_RESET"
    else
        printf "%s%s°C%s" "$C_RED" "$t" "$C_RESET"
    fi
}

get_temperatures() {
    temp_2=$(get_radio_temp WifiMaster0)
    temp_5=$(get_radio_temp WifiMaster1)
    cpu_str=""
    wifi_str=""

    # Получение температуры CPU для aarch64
    if [ "$ARCH" = "aarch64" ]; then
        temp_cpu_raw=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null | tr -d -c '0-9')
        if [ -n "$temp_cpu_raw" ]; then
            cpu_val=$((temp_cpu_raw / 1000))
            cpu_str="CPU: $(color_temp "$cpu_val")"
        fi
    fi

    if ! echo "$temp_2" | grep -qE '^[0-9]+$'; then
        [ -n "$cpu_str" ] && echo " | $cpu_str"
        return
    fi

    # Проверка температуры 5GHz и формирование строки Wi-Fi
    if echo "$temp_5" | grep -qE '^[0-9]+$'; then
        diff=$((temp_5 - temp_2))
        [ $diff -lt 0 ] && diff=$((-diff))
        if [ $diff -lt 3 ]; then
            wifi_str="Wi-Fi: $(color_temp "$temp_5")"
        else
            wifi_str="2.4GHz: $(color_temp "$temp_2") | 5GHz: $(color_temp "$temp_5")"
        fi
    else
        wifi_str="2.4GHz: $(color_temp "$temp_2")"
    fi

    # Сборка итоговой строки (CPU + Wi-Fi)
    [ -n "$cpu_str" ] && wifi_str="$wifi_str | $cpu_str"
    echo " | $wifi_str"
}

get_cpu_model() {
    cpu_list="MT76[0-9A-Za-z]* MT79[0-9A-Za-z]* EN75[0-9A-Za-z]*"
    for pattern in $cpu_list; do
        found=$(strings /lib/libndmMwsController.so 2>/dev/null | grep -oE "$pattern" | head -n 1)
        if [ -n "$found" ]; then
            echo "$found"
            return
        fi
    done
    
    # Fallback на данные из /proc/cpuinfo
    if [ "$ARCH" = "mips" ]; then
        grep 'system type' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm" ]; then
        info=$(grep 'Hardware' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        [ -z "$info" ] && info=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        echo "$info"
    else
        echo "Unknown"
    fi
}

get_architecture() {
    local arch
    if command -v opkg >/dev/null 2>&1; then
        arch=$(opkg print-architecture 2>/dev/null | grep -oE 'mips-3|mipsel-3|aarch64-3' | head -n 1)
        case "$arch" in
            "mips-3") echo "mips" ; return ;;
            "mipsel-3") echo "mipsel" ; return ;;
            "aarch64-3") echo "aarch64" ; return ;;
        esac
    fi
    echo "$ARCH"
}

CPU_MODEL=$(get_cpu_model)
REAL_ARCH=$(get_architecture)
TEMPS=$(get_temperatures)
CPU_DISPLAY="${CPU_MODEL} (${REAL_ARCH})${TEMPS}"

# 3.2. OPKG Storage
format_size() {
    local used=$1
    local total=$2
    local used_mb=$((used / 1024 / 1024))
    local total_mb=$((total / 1024 / 1024))
    if [ "$total_mb" -ge 1024 ]; then
        local total_gb=$((total / 1024 / 1024 / 1024))
        if [ "$used_mb" -lt 1024 ]; then
            printf "%d MB / %d GB" "$used_mb" "$total_gb"
        else
            local used_gb=$((used / 1024 / 1024 / 1024))
            printf "%d / %d GB" "$used_gb" "$total_gb"
        fi
    else
        printf "%d / %d MB" "$used_mb" "$total_mb"
    fi
}

get_opkg_storage() {
    local opkg_label storage_block ls_json free total used
    opkg_label=$(curl -s http://localhost:79/rci/show/sc/opkg/disk | grep -o '"disk": *"[^\"]*"' | cut -d'"' -f4 | sed 's,/$,,;s,:$,,')
    [ -z "$opkg_label" ] && return

    ls_json=$(curl -s http://localhost:79/rci/ls)
    free=$(echo "$ls_json" | grep -A10 "\"$opkg_label:\"" | grep '"free":' | head -1 | grep -o '[0-9]\+')
    total=$(echo "$ls_json" | grep -A10 "\"$opkg_label:\"" | grep '"total":' | head -1 | grep -o '[0-9]\+')

    if [ -n "$free" ] && [ -n "$total" ]; then
        used=$((total - free))
        echo "$(format_size $used $total)"
        return
    fi

    storage_block=$(echo "$ls_json" | grep -E -e '"free":' -e '"label":' -e '"total":' | grep -A1 -B1 "\"label\": \"$opkg_label\"")
    if [ -n "$storage_block" ]; then
        free=$(echo "$storage_block" | grep '"free":' | head -1 | grep -o '[0-9]\+')
        total=$(echo "$storage_block" | grep '"total":' | head -1 | grep -o '[0-9]\+')
        if [ -n "$free" ] && [ -n "$total" ]; then
            used=$((total - free))
            echo "$(format_size $used $total)"
            return
        fi
    fi
}

OPKG_INFO=$(get_opkg_storage)

# 3.3. Меш (Ретрансляторы)
format_uptime_seconds() {
    local uptime=$1
    if [ -z "$uptime" ] || ! echo "$uptime" | grep -qE '^[0-9]+$'; then
        return
    fi
    local days=$((uptime / 86400))
    local hours=$(((uptime % 86400) / 3600))
    local minutes=$(((uptime % 3600) / 60))
    local seconds=$((uptime % 60))

    if [ "$days" -gt 0 ]; then
        printf "%d дн. %02d:%02d:%02d" "$days" "$hours" "$minutes" "$seconds"
    else
        printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
    fi
}

get_mws_members() {
    local mws_json=$(curl -s http://localhost:79/rci/show/mws/member)
    local result=""

    if [ -z "$mws_json" ] || ! echo "$mws_json" | grep -q '^\['; then
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    local repeater_data
    repeater_data=$(echo "$mws_json" | jq -r '
      .[] |
      select(.model != null) |
      "\(.model)|" +
      "\(.fw // "null")|" +
      "\(.system.uptime // "0")|" +
      "\(.backhaul.txrate // .backhaul.speed // "0")"' 2>/dev/null)

    if [ -z "$repeater_data" ]; then
        return 0
    fi

    local first=true
    while IFS='|' read -r model fw uptime speed; do
        local output_line=""
        if [ "$fw" != "null" ]; then
            local uptime_formatted=$(format_uptime_seconds "$uptime")
            output_line=$(printf "%s | %s | %s Мбит/с | %s" "$model" "$fw" "$speed" "$uptime_formatted")
        else
            output_line=$(printf "%s | Не в сети" "$model")
        fi

        if [ "$first" = "true" ]; then
            result="${output_line}"
            first=false
        else
            # Выравнивание 16 пробелов для последующих строк под "   Mesh:        "
            result="${result}\n                ${output_line}"
        fi
    done <<EOF
$repeater_data
EOF

    echo "$result"
}

MESH_INFO=$(get_mws_members)

# 3.4 Слот загрузки
BOOT_SLOT=$(cat /proc/dual_image/boot_current 2>/dev/null)
if [ -n "$BOOT_SLOT" ]; then
    BOOT_SLOT_STR=" (слот: $BOOT_SLOT)"
else
    BOOT_SLOT_STR=""
fi

# --- 4. СИСТЕМНЫЕ РЕСУРСЫ ---

# RAM
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
if [ "$MEM_TOTAL" -gt 0 ]; then
    MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))
else
    MEM_PERC=0
fi

# Uptime
UP_SECONDS=$(cut -d. -f1 /proc/uptime)
UP_DAYS=$((UP_SECONDS / 86400))
UP_HOURS=$(( (UP_SECONDS % 86400) / 3600 ))
UP_MINS=$(( (UP_SECONDS % 3600) / 60 ))
UPTIME_STR="${UP_DAYS}d ${UP_HOURS}h ${UP_MINS}m"

# Load Average
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')

# --- 5. АНАЛИЗ КОМПОНЕНТОВ ---
check_comp() {
    echo "$COMPONENTS" | grep -q "$1" && echo -n "$2 "
}
check_feat() {
    echo "$FEATURES" | grep -q "$1" && echo -n "$2 "
}

VPN_STR=$(
    check_comp "wireguard" "WireGuard"
    check_comp "openvpn" "OpenVPN"
    check_comp "ipsec" "IPsec/IKEv2"
    check_comp "l2tp" "L2TP"
    check_comp "sstp" "SSTP"
    check_comp "zerotier" "ZeroTier"
)

STOR_STR=$(
    check_comp "ntfs" "NTFS"
    check_comp "exfat" "ExFAT"
    check_comp "ext" "EXT4"
    check_comp "tsmb" "SMB"
    check_comp "ftp" "FTP"
)

FEAT_STR=$(
    check_feat "hwnat" "HW-NAT"
    check_feat "ppe" "PPE"
    check_feat "wifi5ghz" "Wi-Fi 5GHz"
    check_feat "wpa3" "WPA3"
    check_feat "usb" "USB"
)

# --- 6. ВЫВОД ИНФОРМАЦИИ ---
echo "==================================================="
echo -e "   ${C_CYAN}Keenetic Router Info${C_RESET}"
echo "==================================================="

echo -e "${C_GREEN}📦 Устройство:${C_RESET}"
echo -e "   Модель:      ${C_WHITE}${MODEL_DISPLAY}${C_RED}${PORT_FLAG}${C_RESET}"
echo -e "   HW ID:       ${HW_ID} (Region: ${REGION})"
echo -e "   Процессор:   ${CPU_DISPLAY}"
echo -e "   Память:      ${C_WHITE}${MEM_USED} MB${C_RESET} / ${MEM_TOTAL} MB занято (${C_YELLOW}${MEM_PERC}%${C_RESET})"

echo -e "\n${C_GREEN}⚙️  Система:${C_RESET}"
echo -e "   Версия ПО:   ${C_WHITE}${TITLE}${C_RESET} (${RELEASE})${BOOT_SLOT_STR}"
[ -z "$PORT_FLAG" ] && echo -e "   Канал:       ${SANDBOX}"
echo -e "   Дата сборки: ${BUILD_DATE}"
[ -n "$OPKG_INFO" ] && echo -e "   OPKG:        ${OPKG_INFO}"
echo -e "   Uptime:      ${UPTIME_STR}"
echo -e "   Load Avg:    ${LOAD_AVG}"

echo -e "\n${C_GREEN}🔌 Компоненты:${C_RESET}"
[ -n "$VPN_STR" ]   && echo -e "   VPN:         ${VPN_STR}"
[ -n "$STOR_STR" ]  && echo -e "   Storage:     ${STOR_STR}"
[ -n "$FEAT_STR" ]  && echo -e "   Features:    ${FEAT_STR}"
[ -n "$MESH_INFO" ] && echo -e "   Mesh:        ${MESH_INFO}"

echo "==================================================="