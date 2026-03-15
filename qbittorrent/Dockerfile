#
# Static qBittorrent (RPi4 Optimized)
#
# Stage 1: Builder
FROM debian:sid-slim AS builder

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# 1. Install System Dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    locales \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    python3 \
    python3-dev \
    perl \
    ninja-build \
    pkg-config \
    libclang-rt-dev \
    ca-certificates \
    linux-headers-generic \
    # Build dependencies
    zlib1g-dev \
    libzstd-dev \
    zstd \
    aria2 \
    && echo "show-progress = off" >> /etc/wgetrc \
    && rm -rf /var/lib/apt/lists/*

# Arguments (Versions)
ARG QBITTORRENT_VERSION
ARG LIBTORRENT_VERSION
ARG QT_VERSION
ARG BOOST_VERSION
ARG OPENSSL_VERSION
ARG MIMALLOC_VERSION

# Common Hardening & Optimization Flags
# Defaults are for "Generic" optimized build (-O3).
# RPi4 specific flags (-mcpu=cortex-a72) are passed via build-args.
ARG CFLAGS="-O3 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"
ARG CXXFLAGS="-O3 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -flto"
ARG LDFLAGS="-Wl,-z,relro -Wl,-z,now -flto"

# Force inclusion of local static libs (overrides/appends to build-args)
ENV CFLAGS="${CFLAGS} -I/usr/local/include" \
    CXXFLAGS="${CXXFLAGS} -I/usr/local/include" \
    LDFLAGS="${LDFLAGS} -L/usr/local/lib" \
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"


# Working Directory
WORKDIR /build

# -----------------------------------------------------------------------------
# 2. Build OpenSSL (Static)
# -----------------------------------------------------------------------------
ARG TARGETARCH
RUN echo "[BUILD] Building OpenSSL ${OPENSSL_VERSION} for ${TARGETARCH}..." && \
    wget -q "https://github.com/openssl/openssl/archive/refs/tags/${OPENSSL_VERSION}.tar.gz" -O openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    cd openssl-openssl-$(echo $OPENSSL_VERSION | sed 's/openssl-//') && \
    # Determine Architecture
    if [ "$TARGETARCH" = "amd64" ]; then \
        OPENSSL_TARGET="linux-x86_64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        OPENSSL_TARGET="linux-aarch64"; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi && \
    ./config --prefix=/usr/local --openssldir=/usr/local/ssl no-shared "$CFLAGS" $OPENSSL_TARGET && \
    make -j$(nproc) && \
    make install_sw && \
    cd .. && rm -rf openssl*

# -----------------------------------------------------------------------------
# 3. Build Mimalloc (Static)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 4. Build Boost (Static)
# -----------------------------------------------------------------------------
# Boost formatting: boost-1.88.0 -> 1.88.0
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

# -----------------------------------------------------------------------------
# 5. Build Qt6 (Static, Minimal)
# -----------------------------------------------------------------------------
    # Qt is massive. We configure a very minimal build for qBittorrent-nox.
    # We fetch the 'qtbase' submodule directly to avoid downloading gigabytes of unused modules.
    RUN echo "[BUILD] Building Qt ${QT_VERSION}..." && \
    QT_VER_CLEAN=$(echo $QT_VERSION | sed 's/v//') && \
    QT_VER_SHORT=$(echo $QT_VER_CLEAN | cut -d. -f1-2) && \
    wget -q "https://download.qt.io/official_releases/qt/${QT_VER_SHORT}/${QT_VER_CLEAN}/submodules/qtbase-everywhere-src-${QT_VER_CLEAN}.tar.xz" -O qt.tar.xz && \
    tar xf qt.tar.xz && \
    cd qtbase-everywhere-src-${QT_VER_CLEAN} && \
    # Configure for static build
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
    # Build qttools (needed for LinguistTools)
    wget -q "https://download.qt.io/official_releases/qt/${QT_VER_SHORT}/${QT_VER_CLEAN}/submodules/qttools-everywhere-src-${QT_VER_CLEAN}.tar.xz" -O qttools.tar.xz && \
    tar xf qttools.tar.xz && \
    cd qttools-everywhere-src-${QT_VER_CLEAN} && \
    /usr/local/bin/qt-configure-module . && \
    cmake --build . --parallel $(nproc) && \
    cmake --install . && \
    cd .. && rm -rf qttools*

# -----------------------------------------------------------------------------
# 6. Build Libtorrent (Static)
# -----------------------------------------------------------------------------
RUN echo "[BUILD] Building Libtorrent ${LIBTORRENT_VERSION}..." && \
    # Clone full repo (needed to checkout specific commit hash for V2)
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

# -----------------------------------------------------------------------------
# 7. Build qBittorrent (Static)
# -----------------------------------------------------------------------------
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
    # Strip binary
    strip /usr/local/bin/qbittorrent-nox && \
    cd .. && rm -rf qBittorrent

# -----------------------------------------------------------------------------
# 8. User Setup
# -----------------------------------------------------------------------------
RUN useradd -u 1000 -s /bin/false -d /home/qbt qbt && \
    mkdir -p /home/qbt/data /usr/share/qbt && \
    chown -R qbt:qbt /home/qbt

# -----------------------------------------------------------------------------
# 9. Prepare Dist Files (Scratch Migration)
# -----------------------------------------------------------------------------
RUN mkdir -p /dist/usr/lib /dist/lib64 /dist/etc /dist/tmp /dist/home/qbt/data /dist/usr/share/qbt && \
    chmod 1777 /dist/tmp && \
    # Create config files
    echo "passwd: files" > /dist/etc/nsswitch.conf && \
    echo "group: files" >> /dist/etc/nsswitch.conf && \
    echo "hosts: files dns" >> /dist/etc/nsswitch.conf && \
    # Copy User/Group
    grep "qbt" /etc/passwd > /dist/etc/passwd && \
    grep "qbt" /etc/group > /dist/etc/group && \
    # Copy SSL Certs
    cp -r /etc/ssl/certs /dist/etc/ssl/ && \
    # Find and Copy Deps
    BIN="/usr/local/bin/qbittorrent-nox" && \
    DEPS=$(ldd $BIN | awk 'BEGIN{ORS=" "}$1~/^\//{print $1}$3~/^\//{print $3}' | sed 's/,//g') && \
    for dep in $DEPS; do \
        dir=$(dirname "$dep"); \
        mkdir -p "/dist$dir"; \
        cp -L "$dep" "/dist$dep"; \
    done && \
    # Copy NSS/Resolv libs (Runtime loaded)
    # Locate lib directory from a known dep (e.g. libc)
    LIBC_PATH=$(ldd $BIN | grep "libc.so" | awk '{print $3}') && \
    LIB_DIR=$(dirname "$LIBC_PATH") && \
    cp -L "$LIB_DIR"/libnss_dns.so* "/dist$LIB_DIR/" && \
    cp -L "$LIB_DIR"/libnss_files.so* "/dist$LIB_DIR/" && \
    cp -L "$LIB_DIR"/libresolv.so* "/dist$LIB_DIR/" && \
    # Ensure correct interpreter path
    INTERP=$(readelf -l $BIN | grep "interpreter" | sed 's/.*: //;s/]//') && \
    if [ ! -f "/dist$INTERP" ]; then \
      mkdir -p "/dist$(dirname $INTERP)"; \
      cp -L "$INTERP" "/dist$INTERP"; \
    fi

# -----------------------------------------------------------------------------
# Stage 2: Final (Scratch)
# -----------------------------------------------------------------------------
FROM scratch
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="qBittorrent-nox (Static, Optimized)"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL maintainer="JoanMorera"

# Copy Dist from Builder
COPY --from=builder /dist /

# Copy Locales (from builder system)
COPY --from=builder /usr/lib/locale /usr/lib/locale

# Copy Binary
COPY --from=builder --chown=qbt:qbt /usr/local/bin/qbittorrent-nox /usr/bin/qbittorrent-nox

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
