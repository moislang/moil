FROM ubuntu:24.04@sha256:9c7f200c07e3d4a03e7249d2c16bf66a51120fb876aa2242cf31451412543289

ARG DEBIAN_FRONTEND=noninteractive
# snl from this repository's snl-seed release (no source build); SHA-256 pinned.
ARG SNL_VERSION=v0.3.0
ARG SNL_ARCHIVE=snl-v0.3.0-linux-x86_64.tar.gz
ARG SNL_SHA256=f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8

# Pin the base image by OCI digest and the direct toolchain package versions.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils=2.42-4ubuntu2.10 \
        ca-certificates=20260816ubuntu0.24.04.2 \
        make=4.3-4.1build2 \
        python3=3.12.3-0ubuntu2.1 \
    && python3 -c "import urllib.request; urllib.request.urlretrieve('https://github.com/snovalang/snl/releases/download/snl-seed-${SNL_VERSION}/${SNL_ARCHIVE}', '/tmp/snl.tar.gz')" \
    && echo "${SNL_SHA256}  /tmp/snl.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/snl.tar.gz -C /usr/local bin/snl builtin \
    && snl --version \
    && rm -rf /tmp/snl.tar.gz /var/lib/apt/lists/*

WORKDIR /workspace
