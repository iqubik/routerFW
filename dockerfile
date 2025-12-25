# file dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
# Устанавливаем зависимости для современных версий OpenWrt
RUN apt-get update && apt-get install -y \
	build-essential git libncurses5-dev zlib1g-dev subversion mercurial autoconf libtool libssl-dev libglib2.0-dev libgmp-dev libmpc-dev libmpfr-dev texinfo gawk python3-distutils python3-setuptools rsync unzip wget file zstd \
	&& rm -rf /var/lib/apt/lists/*
# Копируем минимальный конфиг OpenSSL, чтобы избежать ошибок DSO
COPY openssl.cnf /etc/ssl/openssl.cnf
# Создаем рабочую папку внутри контейнера
WORKDIR /builder_workspace
