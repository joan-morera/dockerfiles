# i2pd-docker

This is a **personal** Docker Image for [i2pd](https://github.com/PurpleI2P/i2pd), built with statically linked libraries, mimalloc and glibc on **Debian Trixie** to ensure compatibility with Distroless.

## Why
I started building it because the official docker image stopped updating for a while, and fell into the Rabbit Hole of making it as efficient as possible, as I mainly run it in a quite congested Raspberry Pi 4.

Performance 

With the RPI 4 build, running it as a Floodfill, with around 50 active tunnels, and 10.000 - 12.000 transit tunnels, limited to 1 CPU.

> [!NOTE]
> This repository contains my personal configuration for running i2pd in a container. I am sharing it for reference in case it is useful to others.

A statically linked, hardened, and minimal container image for [i2pd](https://github.com/PurpleI2P/i2pd).

## Details

*   **Base Image**: `gcr.io/distroless/cc-debian13` (Debian Trixie).
    *   **Minimal Size**: The final image is approximately **30-40 MB**.
    *   **Secure**: No shell, no package manager, non-root user.
*   **Static Linking**: `zlib`, `boost`, `openssl`, `mimalloc`, and `zstd` are linked statically.
*   **Binary Optimization**:
    *   Binary is **stripped** of debugging symbols.
    *   Built with `-O3` and Link Time Optimization (`-flto`).
*   **Hardening Flags** (Applied to both i2pd and mimalloc):
    *   `-fstack-protector-strong`
    *   `-D_FORTIFY_SOURCE=2`
    *   `-Wformat -Werror=format-security`
    *   `-fstack-clash-protection`
*   **Performance Optimizations**:
    *   `-fno-plt` for static builds
    *   `-fgraphite-identity -floop-nest-optimize` for loop optimization
    *   `mimalloc` memory allocator (Release build, also hardened)
    *   NEON SIMD support (ARM64)
*   **CI/CD**: Images are automatically rebuilt when:
    *   A new `i2pd` version is released.
    *   `mimalloc` is updated.
    *   Build dependencies (Debian Trixie) are updated.
    *   The base Distroless image is updated.

## Usage

### Docker Compose

```yaml
services:
  i2pd:
    image: ghcr.io/joan-morera/i2pd:latest
    container_name: i2pd
    restart: unless-stopped
    volumes:
      - ./data:/home/i2pd/data
      # Optional: Mount custom config
      # - ./i2pd.conf:/etc/i2pd/i2pd.conf:ro
    ports:
      - "7070:7070"   # HTTP webconsole
      - "4444:4444"   # HTTP proxy
      - "4447:4447"   # SOCKS proxy
```

### Docker Run

**Standard (Multi-arch):**
```bash
docker run -d \
  --name i2pd \
  -v ./data:/home/i2pd/data \
  -p 7070:7070 -p 4444:4444 -p 4447:4447 \
  ghcr.io/joan-morera/i2pd:latest
```

**Raspberry Pi 4 Optimized:**
```bash
docker run -d \
  --name i2pd \
  -v ./data:/home/i2pd/data \
  -p 7070:7070 -p 4444:4444 -p 4447:4447 \
  ghcr.io/joan-morera/i2pd:rpi4
```

> **Note:** This image uses Distroless and does not contain a shell. It runs `i2pd` directly. Default configuration files are baked into the image but are not automatically copied to the data volume.
