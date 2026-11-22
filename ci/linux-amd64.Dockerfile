FROM ubuntu:24.04@sha256:9c7f200c07e3d4a03e7249d2c16bf66a51120fb876aa2242cf31451412543289

ARG DEBIAN_FRONTEND=noninteractive
ARG SNL_SEED_REVISION=2b5048aaf221527e22ea844f858b5d0f33f149c9

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential=12.10ubuntu1 \
        binutils=2.42-4ubuntu2.10 \
        ca-certificates=20260816ubuntu0.24.04.2 \
        git=1:2.43.0-1ubuntu7.4 \
        make=4.3-4.1build2 \
        python3=3.12.3-0ubuntu2.1 \
    && git clone https://github.com/snovalang/snovac.git /tmp/snovac \
    && git -C /tmp/snovac checkout --detach "${SNL_SEED_REVISION}" \
    && make -C /tmp/snovac -j2 \
    && install -m 0755 /tmp/snovac/build/snl /usr/local/bin/snl \
    && install -d /usr/local/builtin \
    && cp -R /tmp/snovac/builtin/. /usr/local/builtin/ \
    && rm -rf /tmp/snovac /var/lib/apt/lists/*

WORKDIR /workspace
