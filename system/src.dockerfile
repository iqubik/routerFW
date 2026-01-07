#file: system/src.dockerfile v1.1
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \    
    build-essential ccache clang flex bison g++ gawk gcc-multilib g++-multilib \
    gettext git patch swig time rsync unzip file wget curl \    
    libncurses-dev libssl-dev zlib1g-dev libelf-dev libzstd-dev \    
    python3-dev python3-distutils python3-setuptools python3-pyelftools \    
    xsltproc zstd ca-certificates ssl-cert sudo \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 -s /bin/bash build
WORKDIR /home/build/openwrt
RUN mkdir -p dl && chown -R build:build /home/build/openwrt
COPY --chown=build:build openssl.cnf /home/build/openssl.cnf
ENV OPENSSL_CONF=/home/build/openssl.cnf
