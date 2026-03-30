#
# Navidrome (RPi4 Optimized) - Stable Release
#
# Stage 1: Builder
FROM alpine:latest AS builder

# 1. Install System Dependencies (Alpine)
RUN apk add --no-cache \
    build-base \
    git \
    wget \
    curl \
    cmake \
    nasm \
    yasm \
    go \
    nodejs \
    npm \
    python3 \
    tzdata \
    musl-dev \
    autoconf \
    automake \
    libtool \
    pkgconf

# Arguments (Versions = Commit SHAs)
ARG NAVIDROME_VERSION
ARG FFMPEG_VERSION
ARG OPUS_VERSION
ARG MP3LAME_VERSION
ARG TAGLIB_VERSION
ARG ZLIB_VERSION

# Optimization Flags
ARG CFLAGS=""
ARG CXXFLAGS=""
ARG LDFLAGS="-Wl,-z,relro -Wl,-z,now"

# PKG_CONFIG_PATH
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig"

WORKDIR /build

# 2. Build Dependencies (Audio Codecs)

# ZLIB (Static)
RUN echo "[BUILD] Building Zlib (${ZLIB_VERSION})..." && \
    wget -q https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz && \
    tar -xzf zlib-${ZLIB_VERSION}.tar.gz && \
    cd zlib-${ZLIB_VERSION} && \
    ./configure --static --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf zlib-${ZLIB_VERSION} zlib-${ZLIB_VERSION}.tar.gz

# LAME (MP3)
RUN echo "[BUILD] Building Lame (Release: ${MP3LAME_VERSION})..." && \
    wget -q "https://salsa.debian.org/multimedia-team/lame/-/archive/debian/${MP3LAME_VERSION}/lame-debian-${MP3LAME_VERSION}.tar.gz" -O lame.tar.gz && \
    tar xzf lame.tar.gz && \
    cd lame-debian-* && \
    ./configure \
      --prefix=/usr/local \
      --enable-static \
      --disable-shared \
      --enable-nasm \
      --disable-decoder \
      CFLAGS="${CFLAGS}" \
      && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf lame-debian-* lame.tar.gz

# Opus
RUN echo "[BUILD] Building Opus (Release: ${OPUS_VERSION})..." && \
    wget -q "https://github.com/xiph/opus/archive/refs/tags/v${OPUS_VERSION}.tar.gz" -O opus.tar.gz && \
    tar xzf opus.tar.gz && \
    cd opus-* && \
    ./autogen.sh && \
    ./configure \
      --prefix=/usr/local \
      --enable-static \
      --disable-shared \
      --disable-doc \
      --disable-extra-programs \
      CFLAGS="${CFLAGS}" \
      && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf opus-* opus.tar.gz

# TagLib
RUN echo "[BUILD] Building TagLib (Release: ${TAGLIB_VERSION})..." && \
    wget -q "https://github.com/taglib/taglib/archive/refs/tags/v${TAGLIB_VERSION}.tar.gz" -O taglib.tar.gz && \
    tar xzf taglib.tar.gz && \
    cd taglib-* && \
    cmake -B build \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DWITH_ZLIB=OFF \
      -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
      -DCMAKE_C_FLAGS="${CFLAGS}" \
      && \
    cmake --build build --parallel $(nproc) && \
    cmake --install build && \
    cd .. && rm -rf taglib-* taglib.tar.gz

# 3. Build FFmpeg
RUN echo "[BUILD] Building FFmpeg (Release: ${FFMPEG_VERSION})..." && \
    wget -q "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n${FFMPEG_VERSION}.tar.gz" -O ffmpeg.tar.gz && \
    tar xzf ffmpeg.tar.gz && \
    cd FFmpeg-n* && \
    ./configure \
      --prefix=/usr/local \
      --extra-cflags="${CFLAGS}" \
      --extra-cxxflags="${CXXFLAGS}" \
      --pkg-config-flags="--static" \
      --extra-ldflags="${LDFLAGS} -static" \
      --extra-libs="-lpthread -lm" \
      --bindir="/usr/local/bin" \
      --enable-static \
      --disable-shared \
      --disable-ffplay \
      --disable-ffprobe \
      --disable-doc \
      --disable-network \
      --disable-everything \
      --enable-protocol=file \
      --enable-protocol=pipe \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-decoder=aac \
      --enable-decoder=libopus \
      --enable-decoder=mp3 \
      --enable-decoder=flac \
      --enable-decoder=alac \
      --enable-decoder=pcm_s16le \
      --enable-decoder=wavpack \
      --enable-encoder=aac \
      --enable-encoder=libopus \
      --enable-encoder=libmp3lame \
      --enable-muxer=adts \
      --enable-muxer=opus \
      --enable-muxer=mp3 \
      --enable-muxer=flac \
      --enable-muxer=ipod \
      --enable-muxer=null \
      --enable-demuxer=aac \
      --enable-demuxer=ogg \
      --enable-demuxer=mp3 \
      --enable-demuxer=flac \
      --enable-demuxer=wav \
      --enable-demuxer=mov \
      --enable-demuxer=m4a \
      --enable-demuxer=null \
      --enable-filter=aresample \
      --enable-filter=anull \
      --enable-neon \
      --enable-asm \
      && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf ffmpeg*

# 4. Build Navidrome
RUN echo "[BUILD] Building Navidrome (Release: ${NAVIDROME_VERSION})..." && \
    wget -q "https://github.com/navidrome/navidrome/archive/refs/tags/v${NAVIDROME_VERSION}.tar.gz" -O navidrome.tar.gz && \
    tar xzf navidrome.tar.gz && \
    cd navidrome-* && \
    make setup && \
    make buildjs && \
    export CGO_ENABLED=1 && \
    export CGO_LDFLAGS="-L/usr/local/lib -ltag -lz -lstdc++ -lm" && \
    export CGO_CFLAGS="-I/usr/local/include/taglib -I/usr/local/include" && \
    export CGO_CFLAGS_ALLOW="--define-prefix" && \
    go build -buildvcs=false -tags=netgo,osusergo,static_build,sqlite_fts5 -ldflags "-extldflags '-static' -X github.com/navidrome/navidrome/resources.Commit=${NAVIDROME_VERSION} -X github.com/navidrome/navidrome/resources.Tag=${NAVIDROME_VERSION}" -o navidrome . && \
    cp navidrome /usr/local/bin/navidrome && \
    cd .. && rm -rf navidrome-* navidrome.tar.gz

# 5. User Setup & Rootfs Preparation
RUN mkdir -p /rootfs/etc/ssl/certs \
             /rootfs/usr/share/zoneinfo \
             /rootfs/usr/local/bin \
             /rootfs/usr/bin \
             /rootfs/data \
             /rootfs/music && \
    # Users (Alpine syntax)
    adduser -D -u 1000 -h /data -s /bin/false navidrome && \
    grep navidrome /etc/passwd > /rootfs/etc/passwd && \
    grep navidrome /etc/group > /rootfs/etc/group && \
    # Certs & Timezone
    cp /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/certs/ && \
    cp -r /usr/share/zoneinfo/* /rootfs/usr/share/zoneinfo/ && \
    # Binaries
    cp /usr/local/bin/navidrome /rootfs/usr/local/bin/navidrome && \
    cp /usr/local/bin/ffmpeg /rootfs/usr/bin/ffmpeg && \
    # Permissions
    chown -R 1000:1000 /rootfs/data /rootfs/music

# Stage 2: Final (Scratch)
FROM scratch
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="Navidrome Music Server"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL maintainer="JoanMorera"

COPY --from=builder /rootfs /

# Configuration
ENV ND_MUSICFOLDER="/music" \
    ND_DATAFOLDER="/data" \
    ND_SCANSCHEDULE="@every 1h" \
    ND_LOGLEVEL="info" \
    ND_FFMPEG="/usr/bin/ffmpeg"

WORKDIR /data
VOLUME ["/data", "/music"]

EXPOSE 4533

USER navidrome

ENTRYPOINT ["/usr/local/bin/navidrome"]
