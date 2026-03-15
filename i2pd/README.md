# i2pd-docker

Personal Docker image for [i2pd](https://github.com/PurpleI2P/i2pd). Built on Alpine Linux with statically linked libraries and mimalloc. The final image runs from scratch with no base OS.

## Why

The official Docker image stopped updating for a while, which led me down the rabbit hole of making it as efficient as possible. I mainly run it on a congested Raspberry Pi 4.

With the RPi4 build running as a Floodfill, with around 50 active tunnels and 10,000-12,000 transit tunnels, limited to 1 CPU.

> [!NOTE]
> This repository contains my personal configuration for running i2pd in a container. I am sharing it for reference in case it is useful to others.

## Details

**Builder**: `alpine:latest`. Builds i2pd and mimalloc from source.

**Final image**: `scratch`. The image contains only the binary, certificates, and SSL certs. No shell, no package manager, non-root user (`i2pd`, UID 1000). Roughly 10-15 MB.

**Static linking**: `zlib`, `boost`, `openssl`, `mimalloc`, `miniupnpc`, and `zstd` are all linked statically. Because the build uses Alpine's musl libc, the resulting binary is fully self-contained with no runtime shared library dependencies.

**Compiler optimizations**:
- Binary is stripped of debug symbols.
- Optimization level is architecture-aware:
  - `amd64`: `-O3` for maximum speed. Larger caches absorb the extra code size from inlining and vectorization.
  - `arm64`: `-Os` to avoid cache pressure on the Cortex-A72's 48 KB L1 I-cache. OpenSSL handles heavy crypto via hardware kernels anyway.
- Link Time Optimization (`-flto`) with `-fvisibility=hidden` for better cross-unit inlining.
- Dead code stripped at link time via `-ffunction-sections -fdata-sections` and `--gc-sections`.

**Security hardening** (applied to both i2pd and mimalloc):
- `-fstack-protector-strong`
- `-D_FORTIFY_SOURCE=2`
- `-Wformat -Werror=format-security`
- `-fstack-clash-protection`

**Performance**:
- `mimalloc` as the memory allocator (statically linked, Release build, also hardened).
- ARMv8 hardware crypto extensions (`+crypto`) for hardware AES/SHA on arm64.

**Automatic rebuilds** when:
- A new i2pd version is released.
- mimalloc is updated.
- A newer Boost version becomes available on Alpine.
- Any other Alpine package version changes.

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

**Standard (multi-arch):**
```bash
docker run -d \
  --name i2pd \
  -v ./data:/home/i2pd/data \
  -p 7070:7070 -p 4444:4444 -p 4447:4447 \
  ghcr.io/joan-morera/i2pd:latest
```

**Raspberry Pi 4:**
```bash
docker run -d \
  --name i2pd \
  -v ./data:/home/i2pd/data \
  -p 7070:7070 -p 4444:4444 -p 4447:4447 \
  ghcr.io/joan-morera/i2pd:rpi4
```

> **Note:** This image has no shell. It runs `i2pd` directly. The default config is baked in but can be overridden by mounting a custom `i2pd.conf`.
