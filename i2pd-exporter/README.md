# i2pd-exporter-docker

A minimal and self-updating Docker container for [i2pd-exporter](https://github.com/Jercik/i2pd-exporter).

## Container Specifications

- **Base Image**: `scratch`
- **Architecture**: `amd64`, `arm64`
- **Size**: ~2MB (uncompressed)
- **User**: `exporter` (running as non-root)

> [!WARNING]
> This image is built FROM `scratch`. It contains **no shell** (`/bin/sh`, `/bin/bash`) and no system utilities. You cannot `docker exec` into it. Debugging must be done via logs.

## Dependency Tracking & Upgrade Policy

This repository uses an automated CI/CD pipeline that runs daily to ensure the container is always up-to-date with the latest updates.

### Tracking Logic
- **Application Version**: Builds over the latest release tag of [Jercik/i2pd-exporter](https://github.com/Jercik/i2pd-exporter).
- **Base System**: Tracks updates for critical build packages only:
  - `rust`
  - `cargo`

If any of these components change, the image is automatically rebuilt and pushed.

## Configuration

This image requires a running `i2pd` instance with `i2pcontrol` enabled.

For full configuration options (environment variables and flags), please refer to the **[Original Repository Documentation](https://github.com/Jercik/i2pd-exporter#configuration)**.

> [!IMPORTANT]
> **Protocol Scheme**: Match your i2pd configuration. If your control port (7650) uses standard HTTP, use `http://127.0.0.1:7650`. If it uses HTTPS, you might need to add the `--i2pcontrol-tls-insecure` flag.

### I2PControl Configuration
You need to enable the I2PControl interface in your `i2pd.conf`. See the [i2pd documentation](https://docs.i2pd.website/en/latest/user-guide/configuration/#i2pcontrol-interface) for details.

Example `i2pd.conf` snippet:
```ini
[i2pcontrol]
enabled = true
address = 127.0.0.1
port = 7650
password = <YOUR_PASSWORD>
```

## Usage Examples

### Docker Run

```bash
# Note: --metrics-listen-addr 0.0.0.0:9600 allows external access. 
# Use 127.0.0.1:9600 if Prometheus is on the same machine.
docker run -d \
  --name i2pd-exporter \
  --net host \
  --restart unless-stopped \
  ghcr.io/joan-morera/i2pd-exporter:latest \
    --i2pcontrol-address http://127.0.0.1:7650 \
    --i2pcontrol-password <YOUR_PASSWORD> \
    --metrics-listen-addr 0.0.0.0:9600
```

### Docker Compose

```yaml
services:
  i2pd-exporter:
    image: ghcr.io/joan-morera/i2pd-exporter:latest
    container_name: i2pd-exporter
    # Use host networking to easily access local i2pd instance
    network_mode: "host"
    restart: unless-stopped
    # Note: --metrics-listen-addr 0.0.0.0:9600 allows external access.
    # Use 127.0.0.1:9600 if Prometheus is on the same machine.
    command: >
      --i2pcontrol-address http://127.0.0.1:7650
      --i2pcontrol-password <YOUR_PASSWORD>
      --metrics-listen-addr 0.0.0.0:9600
```

### Metrics Endpoint

The metrics are exposed on port **9600** by default.

- **URL**: `http://localhost:9600/metrics`
- **Note**: The endpoint requires the `X-Prometheus-Scrape-Timeout-Seconds` header. Accessing it via a standard browser will return `400 Bad Request`.

**Manual Test:**
```bash
curl -v -H "X-Prometheus-Scrape-Timeout-Seconds: 10" http://localhost:9600/metrics
```

**Prometheus Config:**
```yaml
scrape_configs:
  - job_name: 'i2pd'
    static_configs:
      - targets: ['localhost:9600']
```
