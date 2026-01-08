#!/bin/sh
echo "-----------------------v0.1---------------------------" && \
awk -v RS="" '!/Auto-Installed: yes/ {print $2}' /usr/lib/opkg/status | \
grep -vE "^(base-files|busybox|ca-bundle|cgi-common|dropbear|firewall4|fstools|fwtool|getrandom|iwinfo|jshn|jsonfilter|kernel|kmod-.*|libc|libgcc|libiwinfo-lua|libjson-c|libjson-script|liblua|liblucihttp|liblucihttp-lua|libubox|libubus|libubus-lua|libuci-lua|logd|lua|luci|luci-app-firewall|luci-base|luci-lib-base|luci-lib-ip|luci-lib-jsonc|luci-lib-nixio|luci-mod-admin-full|luci-proto-ipv6|luci-proto-ppp|luci-theme-bootstrap|mtd|netifd|odhcp6c|odhcpd-ipv6only|openwrt-keyring|ppp|procd|rpcd|rpcd-mod-file|rpcd-mod-iwinfo|rpcd-mod-luci|rpcd-mod-rrdns|uboot-envtools|ubus|ubusd|uci|uclient-fetch|uhttpd|uhttpd-mod-ubus|usign|wget-ssl|wpad-basic-wolfssl)$" | \
sort | xargs && \
echo "-----------------------end----------------------------"