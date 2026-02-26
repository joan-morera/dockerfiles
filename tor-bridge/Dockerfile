#
# Multi-stage build for obfs4-bridge
#
# Force update to ensure build fix is picked up

# Stage 1: Builder for lyrebird (obfs4)
FROM debian:trixie-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    golang-go \
    build-essential \
    automake \
    autoconf \
    libevent-dev \
    libssl-dev \
    zlib1g-dev \
    libscrypt-dev \
    libzstd-dev \
    liblzma-dev \
    liblz4-dev \
    libseccomp-dev \
    libcap-dev \
    pkg-config \
    ca-certificates \
    tor-geoipdb \
    && rm -rf /var/lib/apt/lists/*

# Build arguments
ARG LYREBIRD_VERSION
ARG TOR_VERSION
ARG TARGETARCH
ARG ARM64_VARIANT=generic

# Clone and build lyrebird
WORKDIR /go/src/gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird
RUN git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git . && \
    if [ -n "$LYREBIRD_VERSION" ]; then git checkout "$LYREBIRD_VERSION"; fi && \
    export CGO_ENABLED=1 && \
    if [ -d "./cmd/lyrebird" ]; then TARGET="./cmd/lyrebird"; elif [ -d "./obfs4proxy" ]; then TARGET="./obfs4proxy"; else TARGET="."; fi && \
    echo "Building target: $TARGET" && \
    go build -buildmode=pie -trimpath -ldflags "-s -w -linkmode=external -extldflags '-Wl,-z,relro,-z,now'" -o /usr/bin/lyrebird "$TARGET"

# Clone and build Tor
WORKDIR /usr/src/tor
RUN git clone https://gitlab.torproject.org/tpo/core/tor.git . && \
    if [ -n "$TOR_VERSION" ]; then git checkout "$TOR_VERSION"; fi && \
    # Determine architecture-specific library directory and flags
    if [ "$TARGETARCH" = "arm64" ]; then \
      export LIBDIR="/usr/lib/aarch64-linux-gnu"; \
      if [ "$ARM64_VARIANT" = "rpi4" ]; then \
        export CFLAGS_ARCH_SPECIFIC="-mcpu=cortex-a72 -mtune=cortex-a72 -mno-outline-atomics"; \
        echo "Building for RPi4 (Cortex-A72)"; \
      fi \
    else \
      export LIBDIR="/usr/lib/x86_64-linux-gnu"; \
    fi && \
    ./autogen.sh && \
    ./configure \
        --disable-asciidoc \
        --disable-manpages \
        --disable-html-manual \
        --enable-fatal-warnings \
        --enable-gpl \
        --enable-systemd=no \
        --enable-static-tor \
        --enable-zstd \
        --enable-lzma \
        --with-libevent-dir=$LIBDIR \
        --with-openssl-dir=$LIBDIR \
        --with-zlib-dir=$LIBDIR \
        --with-zstd-dir=$LIBDIR \
        --with-lzma-dir=$LIBDIR \
        --with-libscrypt-lib=/usr/lib \
        --with-libscrypt-lib=/usr/lib \
        CFLAGS="-O3 -fno-plt -fgraphite-identity -floop-nest-optimize -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security $CFLAGS_ARCH_SPECIFIC" \
        LDFLAGS="-static -L$LIBDIR -L/usr/lib" \
        LIBS="$LIBDIR/libevent.a $LIBDIR/libevent_openssl.a $LIBDIR/libevent_pthreads.a $LIBDIR/libevent_extra.a $LIBDIR/libssl.a $LIBDIR/libcrypto.a $LIBDIR/libz.a $LIBDIR/libzstd.a $LIBDIR/liblzma.a $LIBDIR/liblz4.a $LIBDIR/libseccomp.a $LIBDIR/libcap.a /usr/lib/libscrypt.a -lpthread -ldl -lm" && \
    make -j$(nproc) 2>&1 | grep --line-buffered -v "requires at runtime the shared libraries from the glibc version used for linking" && \
    make install

# Prepare staging directory for distroless
WORKDIR /stage
# Create directory structure
RUN mkdir -p var/lib/tor var/log/tor etc/tor usr/local/share/tor usr/local/bin
# Copy geoip files
RUN cp /usr/share/tor/geoip usr/local/share/tor/geoip && \
    cp /usr/share/tor/geoip6 usr/local/share/tor/geoip6
# Copy scripts
COPY start-tor.sh usr/local/bin/
COPY get-bridge-line usr/local/bin/

# Fix shell and permissions
# 1. Change shebang from bash to sh (busybox) as distroless debug has no bash
# 2. Create passwd/group files for debian-tor (uid 101)
RUN sed -i 's|#!/usr/bin/env bash|#!/bin/sh|' usr/local/bin/start-tor.sh && \
    sed -i 's|#!/usr/bin/env bash|#!/bin/sh|' usr/local/bin/get-bridge-line && \
    chmod 0755 usr/local/bin/start-tor.sh && \
    chmod 0755 usr/local/bin/get-bridge-line && \
    mkdir -p etc && \
    echo "root:x:0:0:root:/root:/bin/sh" > etc/passwd && \
    echo "debian-tor:x:101:101:,,,:/var/lib/tor:/bin/sh" >> etc/passwd && \
    echo "nonroot:x:65532:65532:nonroot:/home/nonroot:/bin/sh" >> etc/passwd && \
    echo "root:x:0:" > etc/group && \
    echo "debian-tor:x:101:" >> etc/group && \
    echo "nonroot:x:65532:" >> etc/group

# Stage 2: Final image
FROM gcr.io/distroless/base-debian13:debug-nonroot

LABEL maintainer="JoanMorera"

# Use debian-tor user (UID 101)
# We must use the numeric UID because the user doesn't exist yet in the base image's metadata
# until we copy our passwd file, but Docker interprets USER instruction against current state?
# Usually numeric is safer.
USER 101:101

# Copy prepared filesystem from builder with correct ownership for debian-tor
COPY --from=builder --chown=101:101 /stage /

# Copy Tor binary and config
COPY --from=builder --chown=101:101 /usr/local/bin/tor /usr/bin/tor

# Copy lyrebird from builder
COPY --from=builder --chown=101:101 /usr/bin/lyrebird /usr/bin/lyrebird

# Note: setcap is not available in distroless build typically, 
# and we are running as non-root.
# We expect to bind to ports > 1024 or use sysctl/docker caps if needed.

CMD [ "/usr/local/bin/start-tor.sh" ]
