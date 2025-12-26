#file: srcBuilder\src.dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
# Установка зависимостей для сборки OpenWrt из исходников
RUN apt-get update && apt-get install -y \
    build-essential clang flex bison g++ gawk \
    gcc-multilib g++-multilib gettext git libncurses-dev \
    libssl-dev python3-distutils python3-setuptools \
    rsync unzip zlib1g-dev file wget time \
    swig xsltproc \
    && rm -rf /var/lib/apt/lists/*
# Создаем не-root пользователя, так как OpenWrt build system отказывается работать под root
RUN useradd -m -u 1000 -s /bin/bash build
# Переключаемся на пользователя
USER build
WORKDIR /home/build/openwrt
# OpenSSL Config fix
COPY --chown=build:build openssl.cnf /home/build/openssl.cnf
ENV OPENSSL_CONF=/home/build/openssl.cnf
