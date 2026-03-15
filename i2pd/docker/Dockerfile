#
# Copyright (c) 2017-2022, The PurpleI2P Project
#
# Stage 1: Builder
FROM debian:trixie-slim AS builder

# Upgrade base system and install build tools and dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    build-essential \
    g++ \
    cmake \
    wget \
    git \
    ca-certificates \
    zlib1g-dev \
    libboost-filesystem1.88-dev \
    libboost-system1.88-dev \
    libboost-program-options1.88-dev \
    libboost-date-time1.88-dev \
    libboost-thread1.88-dev \
    libboost-iostreams1.88-dev \
    libssl-dev \
    libzstd-dev \
    libminiupnpc-dev \
    && echo "show-progress = off" >> /etc/wgetrc \
    && rm -rf /var/lib/apt/lists/*

# Get the i2pd version from a build argument
ARG BUILDARCH
ARG TARGETARCH
ARG ARM64_VARIANT=generic
ARG I2PD_VERSION
ARG MIMALLOC_VERSION=v3.1.5

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
    tar xvfz mimalloc.tar.gz && \
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
    # Determine architecture-specific library directory, optimization level, and CPU flags.
    if [ "$TARGETARCH" = "arm64" ]; then \
      export OPT_FLAG="-Os"; \
      export LIBDIR="/usr/lib/aarch64-linux-gnu"; \
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
      export LIBDIR="/usr/lib/x86_64-linux-gnu"; \
      export CXXFLAGS_ARCH_EXTRA="-fcf-protection"; \
      echo "[BUILD] Building for AMD64 (x86_64)"; \
    fi && \
    echo "[BUILD] Downloading i2pd ${I2PD_VERSION}..." && \
    wget -q "https://github.com/PurpleI2P/i2pd/archive/refs/tags/${I2PD_VERSION}.tar.gz" -O i2pd.tar.gz && \
    echo "[BUILD] Extracting source..." && \
    tar xvfz i2pd.tar.gz && \
    cd i2pd-$(echo $I2PD_VERSION | sed 's/v//') && \
    echo "[BUILD] Starting compilation with $(nproc) parallel jobs (this may take 5-15 minutes)..." && \
    # Build i2pd
    # We suppress specific linker warnings about glibc runtime dependencies (dlopen, getaddrinfo)
    # because we guarantee the correct runtime environment (debian:sid-slim) in the final image.
    # --gc-sections: drops unreferenced functions/data from statically linked libraries,
    #   reducing the final binary's hot .text footprint (pairs with -ffunction-sections/-fdata-sections).
    make -j$(nproc) WITH_UPNP=yes USE_STATIC=yes CXXFLAGS="$BASE_FLAGS $OPT_FLAG -ffile-prefix-map=/i2pd_src=. ${CXXFLAGS_ARCH_SPECIFIC} ${CXXFLAGS_ARCH_EXTRA}" LDFLAGS="-Wl,-z,relro -Wl,--gc-sections -static -lpthread -lm" LDLIBS="/usr/local/lib/libmimalloc.a ${LIBDIR}/libboost_program_options.a ${LIBDIR}/libssl.a ${LIBDIR}/libcrypto.a ${LIBDIR}/libz.a ${LIBDIR}/libminiupnpc.a -lzstd -latomic -lpthread -ldl" 2>&1 | grep --line-buffered -v "requires at runtime the shared libraries from the glibc version used for linking" && \
    echo "[BUILD] Compilation complete! Stripping and copying binary..." && \
    strip i2pd && \
    cp i2pd /i2pd && \
    echo "[BUILD] Copying certificates..." && \
    cp -r contrib/certificates /certificates && \
    echo "[BUILD] Build stage complete!"

# Prepare user and directories in builder (for scratch)
RUN useradd -u 1000 -s /bin/false -d /home/i2pd i2pd && \
    mkdir -p /home/i2pd/data /usr/share/i2pd /etc/i2pd && \
    chown -R i2pd:i2pd /home/i2pd /usr/share/i2pd /etc/i2pd

# Prepare Dist Files (Scratch Migration)
RUN mkdir -p /dist/usr/lib /dist/lib64 /dist/etc/i2pd /dist/tmp /dist/home/i2pd/data /dist/usr/share/i2pd/certificates /dist/usr/bin && \
    chmod 1777 /dist/tmp && \
    chown -R i2pd:i2pd /dist/home/i2pd /dist/usr/share/i2pd /dist/etc/i2pd && \
    # Create config files
    echo "passwd: files" > /dist/etc/nsswitch.conf && \
    echo "group: files" >> /dist/etc/nsswitch.conf && \
    echo "hosts: files dns" >> /dist/etc/nsswitch.conf && \
    # Copy User/Group
    grep "i2pd" /etc/passwd > /dist/etc/passwd && \
    grep "i2pd" /etc/group > /dist/etc/group && \
    # Copy SSL Certs
    cp -r /etc/ssl/certs /dist/etc/ssl/ && \
    # Copy Application Artifacts
    cp /i2pd /dist/usr/bin/i2pd && \
    chown i2pd:i2pd /dist/usr/bin/i2pd && \
    cp -r /certificates/* /dist/usr/share/i2pd/certificates/ && \
    # Find and Copy Deps
    BIN="/dist/usr/bin/i2pd" && \
    DEPS=$(ldd $BIN | awk 'BEGIN{ORS=" "}$1~/^\//{print $1}$3~/^\//{print $3}' | sed 's/,//g') && \
    for dep in $DEPS; do \
        dir=$(dirname "$dep"); \
        mkdir -p "/dist$dir"; \
        cp -L "$dep" "/dist$dep"; \
    done && \
    # Copy NSS/Resolv libs (Runtime loaded)
    LIBC_PATH=$(ldd $BIN | grep "libc.so" | awk '{print $3}') && \
    if [ -n "$LIBC_PATH" ]; then \
        LIB_DIR=$(dirname "$LIBC_PATH"); \
        cp -L "$LIB_DIR"/libnss_dns.so* "/dist$LIB_DIR/" 2>/dev/null || true; \
        cp -L "$LIB_DIR"/libnss_files.so* "/dist$LIB_DIR/" 2>/dev/null || true; \
        cp -L "$LIB_DIR"/libresolv.so* "/dist$LIB_DIR/" 2>/dev/null || true; \
    fi && \
    # Ensure correct interpreter path
    INTERP=$(readelf -l $BIN | grep "interpreter" | sed 's/.*: //;s/]//') && \
    if [ -n "$INTERP" ] && [ ! -f "/dist$INTERP" ]; then \
      mkdir -p "/dist$(dirname $INTERP)"; \
      cp -L "$INTERP" "/dist$INTERP"; \
    fi

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
