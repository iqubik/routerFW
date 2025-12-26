#!/bin/sh
# Исправляем SSH (критично, иначе не пустит)
[ -d /etc/dropbear ] && chmod 700 /etc/dropbear
[ -f /etc/dropbear/authorized_keys ] && chmod 600 /etc/dropbear/authorized_keys
# Исправляем Shadow (если ты зашиваешь пароль в образ)
[ -f /etc/shadow ] && chmod 600 /etc/shadow
# Исправляем личные ключи SSH (если вдруг зашиваешь id_rsa)
[ -d /root/.ssh ] && chmod 700 /root/.ssh
[ -f /root/.ssh/id_rsa ] && chmod 600 /root/.ssh/id_rsa
exit 0