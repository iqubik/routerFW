#file: srcBuilder/src.dockerfile v1.0
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential clang flex bison g++ gawk \
    gcc-multilib g++-multilib gettext git libncurses-dev \
    libssl-dev python3-distutils python3-setuptools \
    python3-pyelftools libelf-dev \
    rsync unzip zlib1g-dev file wget time \
    swig xsltproc \
    curl ca-certificates ssl-cert sudo \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 -s /bin/bash build
WORKDIR /home/build/openwrt
RUN mkdir -p dl && chown -R build:build /home/build/openwrt
COPY --chown=build:build openssl.cnf /home/build/openssl.cnf
ENV OPENSSL_CONF=/home/build/openssl.cnf
