FROM ubuntu:24.04@sha256:9c7f200c07e3d4a03e7249d2c16bf66a51120fb876aa2242cf31451412543289

ARG DEBIAN_FRONTEND=noninteractive

# No moil here: there is no official Linux ARM64 binary. The host emits the
# ELF assembly and VM results (make bootstrap-native-linux-aarch64-emit);
# this image only assembles, links and runs them.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils=2.42-4ubuntu2.10 \
        make=4.3-4.1build2 \
        python3=3.12.3-0ubuntu2.1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
