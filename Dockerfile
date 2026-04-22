FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    llvm \
    lld \
    make \
    cmake \
    git \
    wget \
    curl \
    patch \
    autoconf \
    automake \
    libtool \
    pkg-config \
    zlib1g-dev \
    python3 \
    python3-pip \
    vim \
    nano \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/AFLplusplus/AFLplusplus.git /opt/AFLplusplus && \
    cd /opt/AFLplusplus && \
    make distrib && \
    make install

WORKDIR /work
