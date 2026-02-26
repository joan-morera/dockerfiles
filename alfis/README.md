# Alfis Docker (Alpine Static)

This is a personal Docker image for [Alfis CLI](https://github.com/Revertron/Alfis), built statically on Alpine Linux.

I wanted to run it on ARM64 but I couldn't find a proper image for it, ergo this repo.

## Features & Improvements
- **Size**: 13MB~ Uncompressed. Contains only the statically linked Alfis binary and the minimal Alpine base.
- **Arch**: AMD64, ARM64, ARMv7 & 386.
- **Security**: Runs as a dedicated non-root user (`alfis`) inside the container (Make sure to set the permissions of the data directory to match this user or remap the user at run time to your desired one).
- **Optimization**: Built with `doh` feature enabled, `LTO`, and `panic=abort` for performance and size optimization.


## Build Policy & Versions
The GitHub Actions workflow runs daily to check for:
1. New **Alfis** releases (tags) from the upstream repository.
2. Updates to the underlying **Alpine** system packages.

If any change is detected, the image is automatically rebuilt and published. 

## Usage
The container comes with a pre-generated **default configuration** located at `/etc/alfis.conf`.
When the container starts, it will initialize the **blockchain database** in the `/var/lib/alfis` directory (which you should mount as a volume).

For detailed information on configuration options, please refer to the [upstream documentation](https://github.com/Revertron/Alfis).

### Basic Usage
```bash
docker run -d \
  --name alfis \
  -p 4244:4244 \
  -p 53:53/udp \
  -v alfis_data:/var/lib/alfis \
  ghcr.io/joan-morera/alfis:latest
```



### Docker Compose
```yaml
services:
  alfis:
    image: ghcr.io/joan-morera/alfis:latest
    container_name: alfis
    restart: unless-stopped
    ports:
      - "4244:4244"
      - "53:53/udp"
    volumes:
      - alfis_data:/var/lib/alfis
      # Optional: Mount custom config
      # - ./my-alfis.conf:/etc/alfis.conf

volumes:
  alfis_data:
```


> Note: Adjust configuration and storage volumes to your liking.
