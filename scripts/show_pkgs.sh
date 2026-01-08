#!/bin/sh

# Подготовка данных
MANUAL_PKGS=$(awk -v RS="" '!/Auto-Installed: yes/ {print $2}' /usr/lib/opkg/status)
ROM_STATUS="/rom/usr/lib/opkg/status"

echo "-----------------------v0.1 (Filtered)---------------------------"
echo "$MANUAL_PKGS" | grep -vE "^(base-files|busybox|ca-bundle|cgi-common|dropbear|firewall4|fstools|fwtool|getrandom|iwinfo|jshn|jsonfilter|kernel|kmod-.*|libc|libgcc|libiwinfo-lua|libjson-c|libjson-script|liblua|liblucihttp|liblucihttp-lua|libubox|libubus|libubus-lua|libuci-lua|logd|lua|luci|luci-app-firewall|luci-base|luci-lib-base|luci-lib-ip|luci-lib-jsonc|luci-lib-nixio|luci-mod-admin-full|luci-proto-ipv6|luci-proto-ppp|luci-theme-bootstrap|mtd|netifd|odhcp6c|odhcpd-ipv6only|openwrt-keyring|ppp|procd|rpcd|rpcd-mod-file|rpcd-mod-iwinfo|rpcd-mod-luci|rpcd-mod-rrdns|uboot-envtools|ubus|ubusd|uci|uclient-fetch|uhttpd|uhttpd-mod-ubus|usign|wget-ssl|wpad-basic-wolfssl)$" | sort | xargs
echo "-----------------------------------------------------------------"

echo ""

echo "-----------------------v0.2 (Profile Clean)----------------------"
# 1. Берем ручные пакеты
# 2. Убираем те, что уже есть в ROM (заводские)
# 3. Убираем модули ядра (kmod), так как в профиле они обычно лишние
# 4. Убираем библиотеки с датами в названии (напр. 20240329)
# 5. Убираем базовые системные либы

echo "$MANUAL_PKGS" | while read pkg; do
    # Проверяем, нет ли пакета в заводской прошивке
    if [ -f "$ROM_STATUS" ] && grep -q "Package: $pkg$" "$ROM_STATUS"; then
        continue
    fi
    echo "$pkg"
done | grep -vE "^kmod-.*" | \
     grep -vE ".*[0-9]{8}.*" | \
     grep -vE "^lib(stdcpp|gcc|atomic|ext2fs|fdisk|blkid|uuid|smartcols|mount|comerr|ss|uuid)[0-9]*$" | \
     sort -u | xargs

echo "-----------------------end---------------------------------------"