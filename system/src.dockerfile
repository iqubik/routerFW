#file: system/src.dockerfile v1.4
# Обновляем базу до 24.04 (GCC 13 внутри)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# В Ubuntu 24.04 есть дефолтный юзер 'ubuntu' с UID 1000. 
# Удаляем его, чтобы освободить UID 1000 для нашего юзера 'build'.
RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu

# Обновляем пакеты.
# Обратите внимание: python3-distutils удален, так как в Python 3.12 он deprecated.
# Добавлен python3-venv, так как новые системы часто требуют venv.
RUN apt-get update && apt-get install -y \    
    mc build-essential ccache clang flex bison g++ gawk gcc-multilib g++-multilib \
    gettext git patch swig time rsync unzip file wget curl dos2unix \
    libncurses-dev libssl-dev zlib1g-dev libelf-dev libzstd-dev \    
    python3-dev python3-setuptools python3-pyelftools python3-venv \    
    xsltproc zstd ca-certificates ssl-cert sudo \
    && rm -rf /var/lib/apt/lists/*

# Создаем пользователя build
RUN useradd -m -u 1000 -s /bin/bash build

WORKDIR /home/build/openwrt
RUN mkdir -p dl && chown -R build:build /home/build/openwrt

# Копируем конфиг OpenSSL (если он у вас есть локально)
COPY --chown=build:build system/openssl.cnf /home/build/openssl.cnf
ENV OPENSSL_CONF=/home/build/openssl.cnf

# На всякий случай настраиваем git safe directory глобально
RUN git config --global --add safe.directory '*'