#!/bin/sh

# 1. Подготовка базовых списков
STATUS_FILE="/usr/lib/opkg/status"
ROM_STATUS="/rom/usr/lib/opkg/status"

# Пакеты, установленные вручную (Manual)
awk -v RS="" '!/Auto-Installed: yes/ {print $2}' "$STATUS_FILE" | sort -u > /tmp/pkgs_manual

# 2. Вывод v0.1 (Ваш текущий фильтр)
echo "-----------------------v0.1 (Filtered)---------------------------"
cat /tmp/pkgs_manual | grep -vE "^(base-files|busybox|ca-bundle|cgi-common|dropbear|firewall4|fstools|fwtool|getrandom|iwinfo|jshn|jsonfilter|kernel|kmod-.*|libc|libgcc|libiwinfo-lua|libjson-c|libjson-script|liblua|liblucihttp|liblucihttp-lua|libubox|libubus|libubus-lua|libuci-lua|logd|lua|luci|luci-app-firewall|luci-base|luci-lib-base|luci-lib-ip|luci-lib-jsonc|luci-lib-nixio|luci-mod-admin-full|luci-proto-ipv6|luci-proto-ppp|luci-theme-bootstrap|mtd|netifd|odhcp6c|odhcpd-ipv6only|openwrt-keyring|ppp|procd|rpcd|rpcd-mod-file|rpcd-mod-iwinfo|rpcd-mod-luci|rpcd-mod-rrdns|uboot-envtools|ubus|ubusd|uci|uclient-fetch|uhttpd|uhttpd-mod-ubus|usign|wget-ssl|wpad-basic-wolfssl)$" | sort | xargs
echo "-----------------------------------------------------------------"

echo ""

# 3. Вывод v0.2 (Умный дифф с ROM)
echo "-----------------------v0.2 (Profile Clean)----------------------"

if [ -f "$ROM_STATUS" ]; then
    # Получаем список пакетов, которые УЖЕ БЫЛИ в заводской прошивке
    awk '/^Package: / {print $2}' "$ROM_STATUS" | sort -u > /tmp/pkgs_rom
    # Вычитаем из ручных пакетов те, что были в ROM
    grep -Fvxf /tmp/pkgs_rom /tmp/pkgs_manual > /tmp/pkgs_diff
else
    # Если ROM не найден, используем список manual как базу
    cp /tmp/pkgs_manual /tmp/pkgs_diff
fi

# Финальная чистка списка diff
cat /tmp/pkgs_diff | \
    grep -vE "^kmod-.*" | \
    grep -vE ".*[0-9]{8}.*" | \
    grep -vE "^lib(stdcpp|gcc|atomic|ext2fs|fdisk|blkid|uuid|smartcols|mount|comerr|ss|uuid)[0-9]*$" | \
    sort -u | xargs

echo "-----------------------end---------------------------------------"

# Чистим за собой
rm /tmp/pkgs_manual /tmp/pkgs_rom /tmp/pkgs_diff 2>/dev/null