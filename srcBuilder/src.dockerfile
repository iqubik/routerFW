#file: srcBuilder/src.dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
# Установка зависимостей + CURL + SUDO
RUN apt-get update && apt-get install -y \
    build-essential clang flex bison g++ gawk \
    gcc-multilib g++-multilib gettext git libncurses-dev \
    libssl-dev python3-distutils python3-setuptools \
    rsync unzip zlib1g-dev file wget time \
    swig xsltproc \
    curl ca-certificates ssl-cert sudo \
    && rm -rf /var/lib/apt/lists/*
# Создаем пользователя build
RUN useradd -m -u 1000 -s /bin/bash build
# Создаем рабочую папку и dl заранее
WORKDIR /home/build/openwrt
RUN mkdir -p dl && chown -R build:build /home/build/openwrt
# OpenSSL Config
COPY --chown=build:build openssl.cnf /home/build/openssl.cnf
ENV OPENSSL_CONF=/home/build/openssl.cnf
# Важно: НЕ переключаемся на USER build здесь, чтобы Entrypoint мог стартовать от root
# USER build