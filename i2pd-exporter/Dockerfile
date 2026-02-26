FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    rust \
    cargo \
    ca-certificates

ARG APP_VERSION

# Build i2pd-exporter (Static)
RUN wget "https://github.com/Jercik/i2pd-exporter/archive/refs/tags/${APP_VERSION}.tar.gz" -O app.tar.gz && \
    tar xvfz app.tar.gz && \
    cd i2pd-exporter-$(echo $APP_VERSION | sed 's/v//') && \
    # Compile statically
    cargo rustc --release --bin i2pd-exporter -- -C target-feature=+crt-static && \
    strip target/release/i2pd-exporter && \
    cp target/release/i2pd-exporter /i2pd-exporter

# Create user files
RUN echo "exporter:x:1000:1000:exporter:/:" > /etc/passwd_exporter && \
    echo "exporter:x:1000:" > /etc/group_exporter

# Final Stage
FROM scratch
LABEL maintainer="JoanMorera"

# Copy user configuration
COPY --from=builder /etc/passwd_exporter /etc/passwd
COPY --from=builder /etc/group_exporter /etc/group

# Copy certificates for HTTPS (reqwest)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy artifacts
COPY --from=builder /i2pd-exporter /i2pd-exporter

USER exporter

ENTRYPOINT ["/i2pd-exporter"]
