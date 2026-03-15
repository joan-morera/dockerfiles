# Stage 1: Build Tor, Lyrebird, and Bootstrapper
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

# 1. Build Go Bootstrapper (Replacement for shell scripts)
WORKDIR /build
COPY bootstrapper.go .
RUN CGO_ENABLED=0 go build -o /usr/bin/bootstrapper bootstrapper.go

# 2. Clone and build lyrebird
WORKDIR /go/src/gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird
RUN git clone -q https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git . && \
    if [ -n "$LYREBIRD_VERSION" ]; then git checkout "$LYREBIRD_VERSION"; fi && \
    export CGO_ENABLED=1 && \
    if [ -d "./cmd/lyrebird" ]; then TARGET="./cmd/lyrebird"; elif [ -d "./obfs4proxy" ]; then TARGET="./obfs4proxy"; else TARGET="."; fi && \
    go build -buildmode=pie -trimpath -ldflags "-s -w -linkmode=external -extldflags '-Wl,-z,relro,-z,now'" -o /usr/bin/lyrebird "$TARGET"

# 3. Clone and build Tor
WORKDIR /usr/src/tor
RUN git clone -q https://gitlab.torproject.org/tpo/core/tor.git . && \
    if [ -n "$TOR_VERSION" ]; then git checkout "$TOR_VERSION"; fi && \
    if [ "$TARGETARCH" = "arm64" ]; then \
      export LIBDIR="/usr/lib/aarch64-linux-gnu"; \
      if [ "$ARM64_VARIANT" = "rpi4" ]; then \
        export CFLAGS_ARCH_SPECIFIC="-mcpu=cortex-a72 -mtune=cortex-a72 -mno-outline-atomics"; \
      fi \
    else \
      export LIBDIR="/usr/lib/x86_64-linux-gnu"; \
    fi && \
    ./autogen.sh && \
    ./configure \
        --disable-asciidoc --disable-manpages --disable-html-manual \
        --enable-fatal-warnings --enable-gpl --enable-systemd=no \
        --enable-static-tor --enable-zstd --enable-lzma \
        --with-libevent-dir=$LIBDIR --with-openssl-dir=$LIBDIR \
        --with-zlib-dir=$LIBDIR --with-zstd-dir=$LIBDIR --with-lzma-dir=$LIBDIR \
        --with-libscrypt-lib=/usr/lib \
        CFLAGS="-O3 -fno-plt -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security $CFLAGS_ARCH_SPECIFIC" \
        LDFLAGS="-static -L$LIBDIR -L/usr/lib" \
        LIBS="$LIBDIR/libevent.a $LIBDIR/libevent_openssl.a $LIBDIR/libevent_pthreads.a $LIBDIR/libevent_extra.a $LIBDIR/libssl.a $LIBDIR/libcrypto.a $LIBDIR/libz.a $LIBDIR/libzstd.a $LIBDIR/liblzma.a $LIBDIR/liblz4.a $LIBDIR/libseccomp.a $LIBDIR/libcap.a /usr/lib/libscrypt.a -lpthread -ldl -lm" && \
    make -j$(nproc) && \
    make install

# 4. Prepare rootfs
WORKDIR /stage
RUN mkdir -p var/lib/tor var/log/tor etc/tor usr/share/tor usr/bin usr/lib
RUN cp /usr/share/tor/geoip usr/share/tor/geoip && \
    cp /usr/share/tor/geoip6 usr/share/tor/geoip6 && \
    cp /usr/local/bin/tor usr/bin/tor && \
    cp /usr/bin/lyrebird usr/bin/lyrebird && \
    cp /usr/bin/bootstrapper usr/bin/bootstrapper && \
    # Create user 1000
    echo "root:x:0:0:root:/root:/bin/sh" > etc/passwd && \
    echo "tor:x:1000:1000:tor:/var/lib/tor:/bin/sh" >> etc/passwd && \
    echo "root:x:0:" > etc/group && \
    echo "tor:x:1000:" >> etc/group && \
    chown -R 1000:1000 var/lib/tor var/log/tor etc/tor

# Stage 2: Final image (Scratch)
FROM scratch
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="Tor Bridge with obfs4"
LABEL org.opencontainers.image.licenses="BSD-3-Clause"
LABEL maintainer="JoanMorera"

COPY --from=builder /stage /
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

USER 1000:1000
ENTRYPOINT ["/usr/bin/bootstrapper"]
