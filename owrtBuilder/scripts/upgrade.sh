#!/bin/sh
# Скрипт для обновления всех пакетов OpenWrt

echo "Шаг 1: Обновление списка пакетов..."
opkg update

echo ""
echo "Шаг 2: Поиск и обновление установленных пакетов..."
opkg list-upgradable | cut -f 1 -d ' ' | xargs -r opkg upgrade

echo ""
echo "Обновление пакетов завершено."
