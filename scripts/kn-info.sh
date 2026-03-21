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

# --- 1. СБОР ДАННЫХ ---
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
  *Cudy*|*WBR3000*|*TR3000*|*WR3000*)     VENDOR_DETECTED="Cudy";     PORT_FLAG=" [Port]" ;;
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

# Формирование имени (Лечим "SmartBox SmartBox")
if [ -n "$VENDOR_DETECTED" ] && [ "$VENDOR_DETECTED" != "Keenetic" ]; then
    case "$MODEL_RAW" in
        *"$VENDOR_DETECTED"*) MODEL_DISPLAY="$MODEL_RAW" ;; # Вендор уже есть в имени
        *) MODEL_DISPLAY="$VENDOR_DETECTED $MODEL_RAW" ;;   # Добавляем вендора
    esac
else
    MODEL_DISPLAY="$MODEL_RAW"
fi

# --- 3. СИСТЕМНЫЕ РЕСУРСЫ ---
# CPU
if [ "$ARCH" = "mips" ]; then
  CPU_INFO=$(grep 'system type' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm" ]; then
  CPU_INFO=$(grep 'Hardware' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
  [ -z "$CPU_INFO" ] && CPU_INFO=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
else
  CPU_INFO="Unknown"
fi
CPU_DISPLAY="${CPU_INFO} (${ARCH})"

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

# --- 4. АНАЛИЗ КОМПОНЕНТОВ ---
# Функции проверки (выводят текст только при вызове внутри $())
check_comp() {
    echo "$COMPONENTS" | grep -q "$1" && echo -n "$2 "
}
check_feat() {
    echo "$FEATURES" | grep -q "$1" && echo -n "$2 "
}

# Собираем данные в переменные! Не выводим сразу!
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

# --- 5. ВЫВОД ИНФОРМАЦИИ ---
echo "==================================================="
echo -e "   ${C_CYAN}Keenetic Router Info${C_RESET}"
echo "==================================================="

echo -e "${C_GREEN}📦 Устройство:${C_RESET}"
echo -e "   Модель:      ${C_WHITE}${MODEL_DISPLAY}${C_RED}${PORT_FLAG}${C_RESET}"
echo -e "   HW ID:       ${HW_ID} (Region: ${REGION})"
echo -e "   Процессор:   ${CPU_DISPLAY}"
echo -e "   Память:      ${C_WHITE}${MEM_USED} MB${C_RESET} / ${MEM_TOTAL} MB занято (${C_YELLOW}${MEM_PERC}%${C_RESET})"

echo -e "\n${C_GREEN}⚙️  Система:${C_RESET}"
echo -e "   Версия ПО:   ${C_WHITE}${TITLE}${C_RESET} (${RELEASE})"
echo -e "   Канал:       ${SANDBOX}"
echo -e "   Дата сборки: ${BUILD_DATE}"
echo -e "   Uptime:      ${UPTIME_STR}"
echo -e "   Load Avg:    ${LOAD_AVG}"

echo -e "\n${C_GREEN}🔌 Компоненты:${C_RESET}"
[ -n "$VPN_STR" ]  && echo -e "   VPN:         ${VPN_STR}"
[ -n "$STOR_STR" ] && echo -e "   Storage:     ${STOR_STR}"
[ -n "$FEAT_STR" ] && echo -e "   Features:    ${FEAT_STR}"

echo "==================================================="