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
    gnuplot-nox \
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
    python3-dev \
    python3-setuptools \
    vim \
    nano \
    ca-certificates \
    qemu-system \
    qemu-user \
    meson \
    ninja-build \
    flex \
    bison \
    libglib2.0-dev \
    libpixman-1-dev \
    libcapstone-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/AFLplusplus/AFLplusplus.git /opt/AFLplusplus && \
    cd /opt/AFLplusplus && \
    make distrib && \
    cd qemu_mode && \
    ./build_qemu_support.sh && \
    cd .. && \
    make install

WORKDIR /work

