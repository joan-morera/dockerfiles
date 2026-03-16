#
# Static qBittorrent (RPi4 Optimized)
#
# Stage 1: Builder
FROM alpine:latest AS builder

# 1. Install System Dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    wget \
    curl \
    python3 \
    python3-dev \
    perl \
    samurai \
    pkgconf \
    ca-certificates \
    linux-headers \
    zlib-dev \
    zstd-dev \
    zstd \
    aria2

# Arguments (Versions)
ARG QBITTORRENT_VERSION
ARG LIBTORRENT_VERSION
ARG QT_VERSION
ARG BOOST_VERSION
ARG OPENSSL_VERSION
ARG MIMALLOC_VERSION

# Common Hardening & Optimization Flags
# Added -static and --gc-sections for fully static build on Alpine
ARG CFLAGS="-O3 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -ffunction-sections -fdata-sections"
ARG CXXFLAGS="-O3 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -flto -fvisibility=hidden -ffunction-sections -fdata-sections"
ARG LDFLAGS="-Wl,-z,relro -Wl,-z,now -Wl,--gc-sections -static -flto"

# Force inclusion of local static libs
ENV CFLAGS="${CFLAGS} -I/usr/local/include" \
    CXXFLAGS="${CXXFLAGS} -I/usr/local/include" \
    LDFLAGS="${LDFLAGS} -L/usr/local/lib" \
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

WORKDIR /build

# 2. Build OpenSSL (Static)
ARG TARGETARCH
RUN echo "[BUILD] Building OpenSSL ${OPENSSL_VERSION} for ${TARGETARCH}..." && \
    wget -q "https://github.com/openssl/openssl/archive/refs/tags/${OPENSSL_VERSION}.tar.gz" -O openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    cd openssl-openssl-$(echo $OPENSSL_VERSION | sed 's/openssl-//') && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        OPENSSL_TARGET="linux-x86_64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        OPENSSL_TARGET="linux-aarch64"; \
    fi && \
    ./config --prefix=/usr/local --openssldir=/usr/local/ssl no-shared "$CFLAGS" $OPENSSL_TARGET && \
    make -j$(nproc) && \
    make install_sw && \
    cd .. && rm -rf openssl*

# 3. Build Mimalloc (Static)
RUN echo "[BUILD] Building Mimalloc ${MIMALLOC_VERSION}..." && \
    wget -q "https://github.com/microsoft/mimalloc/archive/refs/tags/${MIMALLOC_VERSION}.tar.gz" -O mimalloc.tar.gz && \
    tar xzf mimalloc.tar.gz && \
    cd mimalloc-$(echo $MIMALLOC_VERSION | sed 's/v//') && \
    mkdir build && cd build && \
    cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DMI_BUILD_STATIC=ON \
      -DMI_BUILD_SHARED=OFF \
      -DMI_OVERRIDE=ON \
      -DMI_INSTALL_TOPLEVEL=ON \
      -DCMAKE_C_FLAGS="$CFLAGS" \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
      .. && \
    make -j$(nproc) && \
    make install && \
    cd ../.. && rm -rf mimalloc*

# 4. Build Boost (Static)
RUN echo "[BUILD] Building Boost ${BOOST_VERSION}..." && \
    git clone -q --depth 1 --branch ${BOOST_VERSION} --recurse-submodules https://github.com/boostorg/boost.git boost-src && \
    cd boost-src && \
    ./bootstrap.sh --prefix=/usr/local && \
    ./b2 -j$(nproc) install \
      variant=release \
      link=static \
      threading=multi \
      runtime-link=static \
      cxxflags="$CXXFLAGS" \
      --with-system \
      --with-filesystem \
      --with-thread \
      --with-date_time \
      --with-chrono \
    && \
    cd .. && rm -rf boost-src

# 5. Build Qt6 (Static, Minimal)
RUN echo "[BUILD] Building Qt ${QT_VERSION}..." && \
    QT_VER_CLEAN=$(echo $QT_VERSION | sed 's/v//') && \
    QT_VER_SHORT=$(echo $QT_VER_CLEAN | cut -d. -f1-2) && \
    wget -q "https://download.qt.io/official_releases/qt/${QT_VER_SHORT}/${QT_VER_CLEAN}/submodules/qtbase-everywhere-src-${QT_VER_CLEAN}.tar.xz" -O qt.tar.xz && \
    tar xf qt.tar.xz && \
    cd qtbase-everywhere-src-${QT_VER_CLEAN} && \
    ./configure \
      -prefix /usr/local \
      -static \
      -release \
      -no-gui \
      -no-widgets \
      -no-dbus \
      -no-glib \
      -no-icu \
      -no-libpng \
      -no-libjpeg \
      -no-freetype \
      -no-harfbuzz \
      -no-sql-sqlite \
      -no-feature-accessibility \
      -no-feature-testlib \
      -no-feature-printsupport \
      -no-opengl \
      -no-vulkan \
      -openssl-linked \
      -opensource -confirm-license \
      -nomake examples -nomake tests \
      -platform linux-g++ \
      -- \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
      -DCMAKE_C_FLAGS="$CFLAGS" \
      && \
    cmake --build . --parallel $(nproc) && \
    cmake --install . && \
    cd .. && rm -rf qtbase-everywhere-src-${QT_VER_CLEAN} && \
    wget -q "https://download.qt.io/official_releases/qt/${QT_VER_SHORT}/${QT_VER_CLEAN}/submodules/qttools-everywhere-src-${QT_VER_CLEAN}.tar.xz" -O qttools.tar.xz && \
    tar xf qttools.tar.xz && \
    cd qttools-everywhere-src-${QT_VER_CLEAN} && \
    /usr/local/bin/qt-configure-module . && \
    cmake --build . --parallel $(nproc) && \
    cmake --install . && \
    cd .. && rm -rf qttools*

# 6. Build Libtorrent (Static)
RUN echo "[BUILD] Building Libtorrent ${LIBTORRENT_VERSION}..." && \
    git clone -q --recurse-submodules https://github.com/arvidn/libtorrent.git && \
    cd libtorrent && \
    git checkout ${LIBTORRENT_VERSION} && \
    git submodule update --init --recursive && \
    cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_CXX_STANDARD=20 \
      -DBUILD_SHARED_LIBS=OFF \
      -Dstatic_runtime=ON \
      -Ddeprecated-functions=OFF \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
      && \
    cmake --build build --parallel $(nproc) && \
    cmake --install build && \
    cd .. && rm -rf libtorrent

# 7. Build qBittorrent (Static)
RUN echo "[BUILD] Building qBittorrent ${QBITTORRENT_VERSION}..." && \
    git clone -q --depth 1 --branch ${QBITTORRENT_VERSION} https://github.com/qbittorrent/qBittorrent.git && \
    cd qBittorrent && \
    cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DGUI=OFF \
      -DQT6=ON \
      -DSTACKTRACE=OFF \
      -DCMAKE_CXX_STANDARD=20 \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
      -DLIBS="-lmimalloc -latomic -lssl -lcrypto" \
      && \
    cmake --build build --parallel $(nproc) && \
    cmake --install build && \
    strip /usr/local/bin/qbittorrent-nox && \
    cd .. && rm -rf qBittorrent

# 8. User Setup
RUN adduser -D -u 1000 -h /home/qbt -s /bin/false qbt && \
    mkdir -p /home/qbt/data /usr/share/qbt && \
    chown -R qbt:qbt /home/qbt

# 9. Prepare Dist Files (Scratch Migration)
# Binary is fully static (musl), no glibc shared libs needed.
RUN mkdir -p /dist/etc/ssl /dist/tmp /dist/home/qbt/data /dist/usr/bin && \
    chmod 1777 /dist/tmp && \
    grep "qbt" /etc/passwd > /dist/etc/passwd && \
    grep "qbt" /etc/group > /dist/etc/group && \
    cp -r /etc/ssl/certs /dist/etc/ssl/ && \
    cp /usr/local/bin/qbittorrent-nox /dist/usr/bin/qbittorrent-nox

# Stage 2: Final (Scratch)
FROM scratch
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="qBittorrent-nox (Static, Optimized)"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL maintainer="JoanMorera"

# Copy Dist from Builder
COPY --from=builder /dist /

# Env
ENV HOME="/home/qbt" \
    XDG_CONFIG_HOME="/home/qbt" \
    XDG_DATA_HOME="/home/qbt" \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

# Runtime Config
USER qbt
WORKDIR /home/qbt

EXPOSE 8080 6881 6881/udp

ENTRYPOINT ["/usr/bin/qbittorrent-nox"]
