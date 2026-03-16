# Stage 1: Build Tor, Lyrebird, and Bootstrapper
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    go \
    build-base \
    automake \
    autoconf \
    libevent-dev \
    openssl-dev \
    zlib-dev \
    zstd-dev \
    xz-dev \
    lz4-dev \
    libseccomp-dev \
    libcap-dev \
    pkgconf \
    ca-certificates \
    musl-dev

# Build arguments
ARG LYREBIRD_VERSION
ARG TOR_VERSION
ARG TARGETARCH
ARG ARM64_VARIANT=generic

# 1. Build Go Bootstrapper
WORKDIR /build
COPY bootstrapper.go .
RUN CGO_ENABLED=0 go build -o /usr/bin/bootstrapper bootstrapper.go

# 2. Clone and build lyrebird
WORKDIR /go/src/gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird
RUN git clone -q https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git . && \
    if [ -n "$LYREBIRD_VERSION" ]; then git checkout "$LYREBIRD_VERSION"; fi && \
    export CGO_ENABLED=1 && \
    if [ -d "./cmd/lyrebird" ]; then TARGET="./cmd/lyrebird"; elif [ -d "./obfs4proxy" ]; then TARGET="./obfs4proxy"; else TARGET="."; fi && \
    go build -buildmode=pie -trimpath -ldflags "-s -w -linkmode=external -extldflags '-static -Wl,-z,relro,-z,now'" -o /usr/bin/lyrebird "$TARGET"

# 3. Clone and build Tor
WORKDIR /usr/src/tor
RUN git clone -q https://gitlab.torproject.org/tpo/core/tor.git . && \
    if [ -n "$TOR_VERSION" ]; then git checkout "$TOR_VERSION"; fi && \
    if [ "$TARGETARCH" = "arm64" ] && [ "$ARM64_VARIANT" = "rpi4" ]; then \
      export CFLAGS_ARCH_SPECIFIC="-mcpu=cortex-a72 -mtune=cortex-a72 -mno-outline-atomics"; \
    fi && \
    ./autogen.sh && \
    ./configure \
        --disable-asciidoc --disable-manpages --disable-html-manual \
        --enable-fatal-warnings --enable-gpl --enable-systemd=no \
        --enable-static-tor --enable-zstd --enable-lzma \
        --with-libevent-dir=/usr/lib --with-openssl-dir=/usr/lib \
        --with-zlib-dir=/usr/lib --with-zstd-dir=/usr/lib --with-lzma-dir=/usr/lib \
        CFLAGS="-O3 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security $CFLAGS_ARCH_SPECIFIC" \
        LDFLAGS="-static -L/usr/lib" \
        LIBS="/usr/lib/libevent.a /usr/lib/libevent_openssl.a /usr/lib/libevent_pthreads.a /usr/lib/libevent_extra.a /usr/lib/libssl.a /usr/lib/libcrypto.a /usr/lib/libz.a /usr/lib/libzstd.a /usr/lib/liblzma.a /usr/lib/liblz4.a /usr/lib/libseccomp.a /usr/lib/libcap.a -lpthread -ldl -lm" && \
    make -j$(nproc) && \
    make install

# 4. Prepare rootfs
WORKDIR /stage
RUN mkdir -p var/lib/tor var/log/tor etc/tor usr/share/tor usr/bin usr/lib
RUN cp /usr/src/tor/src/config/geoip usr/share/tor/geoip && \
    cp /usr/src/tor/src/config/geoip6 usr/share/tor/geoip6 && \
    cp /usr/local/bin/tor usr/bin/tor && \
    cp /usr/bin/lyrebird usr/bin/lyrebird && \
    cp /usr/bin/bootstrapper usr/bin/bootstrapper

# Create user using Alpine syntax
RUN adduser -D -u 1000 -h /var/lib/tor -s /bin/false tor && \
    grep "tor" /etc/passwd > /stage/etc/passwd && \
    grep "tor" /etc/group > /stage/etc/group && \
    echo "root:x:0:0:root:/root:/bin/sh" > /stage/etc/passwd && \
    grep "tor" /etc/passwd >> /stage/etc/passwd && \
    echo "root:x:0:" > /stage/etc/group && \
    grep "tor" /etc/group >> /stage/etc/group && \
    chown -R 1000:1000 var/lib/tor var/log/tor etc/tor
# Wait, I should make sure the rootfs etc/passwd is correct.
# Correcting the rootfs prep.

RUN mkdir -p /stage/etc && \
    echo "root:x:0:0:root:/root:/bin/sh" > /stage/etc/passwd && \
    echo "tor:x:1000:1000:tor:/var/lib/tor:/bin/sh" >> /stage/etc/passwd && \
    echo "root:x:0:" > /stage/etc/group && \
    echo "tor:x:1000:" >> /stage/etc/group && \
    chown -R 1000:1000 /stage/var/lib/tor /stage/var/log/tor /stage/etc/tor

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
