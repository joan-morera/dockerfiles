#
# Copyright (c) 2017-2022, The PurpleI2P Project
#

# Stage 1: Builder
FROM alpine:latest AS builder

ARG BOOST_PKG_VERSION

RUN apk add --no-cache \
    build-base \
    cmake \
    wget \
    ca-certificates \
    boost${BOOST_PKG_VERSION}-dev \
    boost${BOOST_PKG_VERSION}-static \
    openssl-dev \
    openssl-libs-static \
    zlib-dev \
    zlib-static \
    zstd-dev \
    zstd-static \
    miniupnpc-dev \
    linux-headers

ARG BUILDARCH
ARG TARGETARCH
ARG ARM64_VARIANT=generic
ARG I2PD_VERSION
ARG MIMALLOC_VERSION

# Common security hardening and LTO flags (optimization level is architecture-specific).
# Removed: -fno-plt (no-op with -static), -fgraphite-identity and -floop-nest-optimize
#   (Graphite loop transforms have no effect without a complete Graphite pass pipeline;
#    i2pd hot paths are packet dispatch/state-machines, not numeric kernels).
# Added:  -fvisibility=hidden (improves LTO cross-TU inlining quality),
#         -ffunction-sections -fdata-sections (enables linker dead-code elimination via --gc-sections).
ARG BASE_FLAGS="-flto -fvisibility=hidden -ffunction-sections -fdata-sections -fstack-protector-strong -fstack-clash-protection -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -Wdate-time"

# Build mimalloc from source (static)
RUN export CXXFLAGS_ARCH_SPECIFIC="" && \
    # Optimization level is architecture-aware:
    #   amd64:  -O3  — larger caches absorb the bigger .text from inlining/unrolling/vectorization.
    #   arm64:  -Os  — Cortex-A72 has a 48 KB L1 I-cache; -O3 inlining bloat causes cache thrashing
    #                  while heavy crypto is handled by OpenSSL hardware kernels anyway.
    if [ "$TARGETARCH" = "arm64" ]; then \
      export OPT_FLAG="-Os"; \
      if [ "$ARM64_VARIANT" = "rpi4" ]; then \
        # +crypto suffix enables ARMv8 AES/SHA hardware instructions used by OpenSSL
        export CXXFLAGS_ARCH_SPECIFIC="-mcpu=cortex-a72+crypto -mtune=cortex-a72 -mno-outline-atomics"; \
      fi \
    else \
      export OPT_FLAG="-O3"; \
    fi && \
    echo "[BUILD] Downloading mimalloc ${MIMALLOC_VERSION}..." && \
    wget -q "https://github.com/microsoft/mimalloc/archive/refs/tags/${MIMALLOC_VERSION}.tar.gz" -O mimalloc.tar.gz && \
    tar xfz mimalloc.tar.gz && \
    cd mimalloc-$(echo ${MIMALLOC_VERSION} | sed 's/v//') && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DMI_BUILD_STATIC=ON -DMI_BUILD_SHARED=OFF -DMI_OVERRIDE=ON -DMI_NO_OPT_ARCH=ON -DMI_INSTALL_TOPLEVEL=ON -DCMAKE_C_FLAGS="$BASE_FLAGS $OPT_FLAG $CXXFLAGS_ARCH_SPECIFIC" -DCMAKE_CXX_FLAGS="$BASE_FLAGS $OPT_FLAG $CXXFLAGS_ARCH_SPECIFIC" .. && \
    make -j$(nproc) && \
    make install && \
    cd ../.. && \
    rm -rf mimalloc*

# Download and build i2pd
RUN export CXXFLAGS_ARCH_SPECIFIC="" && \
    export CXXFLAGS_ARCH_EXTRA="" && \
    # Determine architecture-specific optimization level and CPU flags.
    # On Alpine all libs live in /usr/lib regardless of arch (no multilib subdirs).
    if [ "$TARGETARCH" = "arm64" ]; then \
      export OPT_FLAG="-Os"; \
      if [ "$ARM64_VARIANT" = "rpi4" ]; then \
        # +crypto: enables ARMv8 AES/SHA hardware extensions (critical for OpenSSL crypto kernels)
        export CXXFLAGS_ARCH_SPECIFIC="-mcpu=cortex-a72+crypto -mtune=cortex-a72 -mno-outline-atomics"; \
        export CXXFLAGS_ARCH_EXTRA="-mbranch-protection=standard"; \
        echo "[BUILD] Building for ARM64 (aarch64) with Raspberry Pi 4 optimizations"; \
      else \
        # Generic arm64: explicit +crypto march for hardware AES/SHA on any ARMv8 capable host
        export CXXFLAGS_ARCH_EXTRA="-mbranch-protection=standard -march=armv8-a+crypto"; \
        echo "[BUILD] Building for ARM64 (aarch64) generic"; \
      fi \
    else \
      export OPT_FLAG="-O3"; \
      export CXXFLAGS_ARCH_EXTRA="-fcf-protection"; \
      echo "[BUILD] Building for AMD64 (x86_64)"; \
    fi && \
    echo "[BUILD] Downloading i2pd ${I2PD_VERSION}..." && \
    wget -q "https://github.com/PurpleI2P/i2pd/archive/refs/tags/${I2PD_VERSION}.tar.gz" -O i2pd.tar.gz && \
    echo "[BUILD] Extracting source..." && \
    tar xfz i2pd.tar.gz && \
    cd i2pd-$(echo $I2PD_VERSION | sed 's/v//') && \
    echo "[BUILD] Starting compilation with $(nproc) parallel jobs (this may take 5-15 minutes)..." && \
    # Build i2pd as a fully static binary against musl libc.
    # Alpine's musl supports complete static linking (including DNS/NSS), so the final binary
    # has no runtime shared library dependencies at all.
    # --gc-sections: drops unreferenced functions/data from statically linked libraries,
    #   reducing the final binary's hot .text footprint (pairs with -ffunction-sections/-fdata-sections).
    make -j$(nproc) WITH_UPNP=yes USE_STATIC=yes CXXFLAGS="$BASE_FLAGS $OPT_FLAG -ffile-prefix-map=/i2pd_src=. ${CXXFLAGS_ARCH_SPECIFIC} ${CXXFLAGS_ARCH_EXTRA}" LDFLAGS="-Wl,-z,relro -Wl,--gc-sections -static" LDLIBS="/usr/local/lib/libmimalloc.a /usr/lib/libboost_program_options.a /usr/lib/libssl.a /usr/lib/libcrypto.a /usr/lib/libz.a /usr/lib/libminiupnpc.a /usr/lib/libzstd.a -latomic -lpthread -ldl" && \
    echo "[BUILD] Compilation complete! Stripping and copying binary..." && \
    strip i2pd && \
    cp i2pd /i2pd && \
    echo "[BUILD] Copying certificates..." && \
    cp -r contrib/certificates /certificates && \
    echo "[BUILD] Build stage complete!"

# Prepare user and directories in builder (for scratch)
RUN adduser -D -u 1000 -h /home/i2pd -s /bin/false i2pd && \
    mkdir -p /home/i2pd/data /etc/i2pd && \
    chown -R i2pd:i2pd /home/i2pd /etc/i2pd

# Prepare Dist Files (Scratch Migration)
# The binary is fully static (musl), so no shared libraries need to be copied.
RUN mkdir -p /dist/etc/ssl /dist/etc/i2pd /dist/tmp /dist/home/i2pd/data /dist/usr/share/i2pd/certificates /dist/usr/bin && \
    chmod 1777 /dist/tmp && \
    chown -R i2pd:i2pd /dist/home/i2pd /dist/etc/i2pd && \
    # Copy User/Group
    grep "i2pd" /etc/passwd > /dist/etc/passwd && \
    grep "i2pd" /etc/group > /dist/etc/group && \
    # Copy SSL Certs
    cp -r /etc/ssl/certs /dist/etc/ssl/ && \
    # Copy Application Artifacts
    cp /i2pd /dist/usr/bin/i2pd && \
    chown i2pd:i2pd /dist/usr/bin/i2pd && \
    cp -r /certificates/* /dist/usr/share/i2pd/certificates/

# Stage 2: Final image (Scratch)
FROM scratch
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="i2pd (C++ I2P router)"
LABEL org.opencontainers.image.licenses="BSD-3-Clause"
LABEL maintainer="JoanMorera"

ARG I2PD_VERSION
ENV I2PD_HOME="/home/i2pd" \
    DATA_DIR="/home/i2pd/data"

# Copy Dist from Builder
COPY --from=builder /dist /

COPY --chown=i2pd:i2pd i2pd-docker.conf /etc/i2pd/i2pd.conf

VOLUME "$DATA_DIR"
EXPOSE 7070 4444 4447 7656 2827 7654 7650
USER i2pd

# Run i2pd directly
ENTRYPOINT ["/usr/bin/i2pd"]
CMD ["--datadir=/home/i2pd/data"]
