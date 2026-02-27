#!/bin/sh
# file: scripts/upgrade.sh
# Скрипт для обновления всех пакетов OpenWrt
# Говорят так делать не очень хорошо, но для домашнего роутера с ограниченным числом пакетов - сойдет.

echo "Шаг 1: Обновление списка пакетов..."
opkg update

echo ""
echo "Шаг 2: Поиск и обновление установленных пакетов..."
opkg list-upgradable | cut -f 1 -d ' ' | xargs -r opkg upgrade

echo ""
echo "Обновление пакетов завершено."
# checksum:MD5=260ae10b0344325169c7e1c46629c91f