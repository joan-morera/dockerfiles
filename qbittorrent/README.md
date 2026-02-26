# qBittorrent Static

A highly optimized, static build of `qBittorrent-nox` running on a `scratch` (empty) container.

I built this because I wanted something lighter and more performant than existing alternatives. It replaces standard memory allocators with `mimalloc` to reduce CPU spikes and uses aggressive compile-time optimizations.

Because it runs on `scratch`, the final image contains **only** the qBittorrent binary and the handful of system libraries it needs to run. No shell, no package manager, no bloat.

## Why use this image?

- **Tiny**: ~45MB compressed (~64MB uncompressed).
- **Secure**: Runs as a non-root user (`qbt`) in an empty container. 
- **Fast**: 
  - Compiled with `LTO` (Link Time Optimization) and `-O3`.
  - Uses `mimalloc` (Microsoft's scalable allocator) instead of the standard `malloc`.
  - **AMD64** builds use modern `x86-64-v3` instructions (AVX2, FMA).
  - **Raspberry Pi 4** builds are tuned specifically for the Cortex-A72 CPU.
  - **Dependencies**: All libraries (Qt6, Libtorrent, Boost, OpenSSL) are built from source with the same optimizations.

## Technical Internals

### Architecture
- **Builder**: `debian:sid-slim`
- **Runtime**: `scratch`. We manually identify and copy only the `glibc`, `nss`, and `resolv` libraries required for networking and DNS.

### Configuration
Everything is built statically where possible.
- **qBittorrent**: GUI disabled, Qt6 enabled, stripped binary.
- **Qt6**: Minimal build. No GUI, no widgets, no DBus. Just the core networking and tools.
- **Libtorrent**: Built without deprecated functions.

### Hardening Matches
We don't sacrifice security for speed. The binary is hardened with:
- Stack Smashing Protection (`-fstack-protector-strong`)
- Buffer Overflow Protection (`-D_FORTIFY_SOURCE=2`)
- Format String Protection (`-Wformat -Werror=format-security`)
- Full RELRO (Read-Only Relocations) to prevent memory corruption attacks.

## Versions & Updates
An automated system checks for updates daily.

| Component | V1 Package | V2 Package |
| :--- | :--- | :--- |
| **qBittorrent** | release-5.1.4 | release-5.1.4 |
| **Libtorrent** | v1.2.20 | HEAD (049965b6) |
| **Qt** | v6.10.1 | v6.10.1 |
| **Boost** | boost-1.86.0 | boost-1.90.0 |
| **OpenSSL** | openssl-3.6.1 | openssl-3.6.1 |
| **Base Image** | scratch | scratch |

## Packages
We publish two versions. If you aren't sure, use **Package 1**.

### Package 1: `qbittorrent` (Libtorrent V1)
Best for general use, wider compatibility, and performance on lower-end hardware.

| Tag | Use Case |
| :--- | :--- |
| `latest` | Generic Stable (AMD64/ARM64) |
| `amd64` | **Performance** (requires modern CPU with AVX2) |
| `rpi4` | **Raspberry Pi 4** (Specific Cortex-A72 tuning) |

### Package 2: `qbittorrent-lt2` (Libtorrent V2)
For users who need BitTorrent v2 support.

| Tag | Use Case |
| :--- | :--- |
| `latest` | Generic Stable |
| `amd64` | Performance (AVX2) |
| `rpi4` | Raspberry Pi 4 |

## Quick Start

### Docker Run
```bash
docker run -d \
  --name qbittorrent \
  -p 8080:8080 \
  -p 6881:6881 \
  -p 6881:6881/udp \
  -v qbt_data:/home/qbt \
  ghcr.io/joan-morera/qbittorrent:latest
```

### Docker Compose
```yaml
services:
  qbittorrent:
    image: ghcr.io/joan-morera/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    volumes:
      - qbt_data:/home/qbt
      - /path/to/downloads:/downloads

volumes:
  qbt_data:
```
> **Note**: Config/Processing happens in `/home/qbt`. Mount this to keep your settings persistent.
