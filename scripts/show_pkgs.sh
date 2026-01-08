#!/bin/sh

# 1. Поиск путей (на разных прошивках они могут быть /usr/lib/opkg или /lib/opkg)
[ -f /usr/lib/opkg/status ] && STATUS="/usr/lib/opkg/status" || STATUS="/lib/opkg/status"
[ -f /rom$STATUS ] && ROM_STATUS="/rom$STATUS" || ROM_STATUS=""

# Временные файлы
TMP_MANUAL="/tmp/pkgs_manual.txt"
TMP_ROM="/tmp/pkgs_rom.txt"

# Собираем пакеты, которые НЕ помечены как Auto-Installed
awk -v RS="" '!/Auto-Installed: yes/ {print $2}' "$STATUS" | sort -u > "$TMP_MANUAL"

echo "-----------------------v0.1 (Hardcoded Filter)-------------------"
# Ваш проверенный фильтр
cat "$TMP_MANUAL" | grep -vE "^(base-files|busybox|ca-bundle|cgi-common|dropbear|firewall4|fstools|fwtool|getrandom|iwinfo|jshn|jsonfilter|kernel|kmod-.*|libc|libgcc|libiwinfo-lua|libjson-c|libjson-script|liblua|liblucihttp|liblucihttp-lua|libubox|libubus|libubus-lua|libuci-lua|logd|lua|luci|luci-app-firewall|luci-base|luci-lib-base|luci-lib-ip|luci-lib-jsonc|luci-lib-nixio|luci-mod-admin-full|luci-proto-ipv6|luci-proto-ppp|luci-theme-bootstrap|mtd|netifd|odhcp6c|odhcpd-ipv6only|openwrt-keyring|ppp|procd|rpcd|rpcd-mod-file|rpcd-mod-iwinfo|rpcd-mod-luci|rpcd-mod-rrdns|uboot-envtools|ubus|ubusd|uci|uclient-fetch|uhttpd|uhttpd-mod-ubus|usign|wget-ssl|wpad-basic-wolfssl)$" | sort | xargs
echo "-----------------------------------------------------------------"

echo ""

echo "-----------------------v0.2 (Smart ROM Diff)---------------------"
if [ -n "$ROM_STATUS" ]; then
    # Получаем список пакетов из заводской прошивки
    awk '/^Package: / {print $2}' "$ROM_STATUS" | sort -u > "$TMP_ROM"
    
    # Сравниваем через awk (выводим только те, что есть в MANUAL, но нет в ROM)
    awk 'NR==FNR {rom[$1]; next} !($1 in rom)' "$TMP_ROM" "$TMP_MANUAL" > /tmp/pkgs_diff.txt
else
    # Если ROM не найден, берем всё из manual
    cp "$TMP_MANUAL" /tmp/pkgs_diff.txt
fi

# Финальная очистка (удаляем библиотеки с датами, kmod-ы и системные либы)
cat /tmp/pkgs_diff.txt | \
    grep -vE "^kmod-.*" | \
    grep -vE ".*[0-9]{8}.*" | \
    grep -vE "^lib(stdcpp|gcc|atomic|ext2fs|fdisk|blkid|uuid|smartcols|mount|comerr|ss|uuid|json-c|pcre2|pcap|curl|uv|wolfssl|openssl|mbedtls|nl-tiny|blobmsg-json|ubox|ubus|uci|uclient|ucode|udebug|unbound|ustream-openssl|websockets)[0-9]*$" | \
    sort -u | xargs

# Проверка на пустоту
if [ ! -s /tmp/pkgs_diff.txt ]; then
    echo "[!] Список v0.2 пуст. Это значит, что все установленные вручную пакеты уже присутствуют в ROM (вшиты в прошивку)."
fi

echo "-----------------------end---------------------------------------"

# Очистка
rm "$TMP_MANUAL" "$TMP_ROM" /tmp/pkgs_diff.txt 2>/dev/null