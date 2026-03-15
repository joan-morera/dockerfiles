FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    rust \
    cargo \
    openssl-dev \
    openssl-libs-static \
    zlib-static \
    pkgconf

ARG ALFIS_VERSION
ENV OPENSSL_STATIC=1
ENV OPENSSL_LIB_DIR=/usr/lib
ENV OPENSSL_INCLUDE_DIR=/usr/include
ENV CARGO_PROFILE_RELEASE_LTO=true
ENV CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
ENV CARGO_PROFILE_RELEASE_PANIC=abort
ENV CARGO_PROFILE_RELEASE_STRIP=symbols


# Build Alfis
# We find the directory name dynamically because the tarball extracts to "Alfis-<tag without v sometimes>" or similar
RUN wget -q "https://github.com/Revertron/Alfis/archive/refs/tags/${ALFIS_VERSION}.tar.gz" -O alfis.tar.gz && \
    tar xvfz alfis.tar.gz && \
    cd Alfis-* && \
    cargo rustc --release --bin alfis --no-default-features --features="doh" -- -C target-feature=+crt-static && \
    cp target/release/alfis /alfis

# Final Stage
FROM alpine:latest
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="Alfis Alternative Free Identity System"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL maintainer="JoanMorera"

ARG srv_port=4244
ARG dns_port=53

# Runtime dependencies (none needed for static build)

ENV ALFIS_HOME="/var/lib/alfis"

# Create user and dirs
RUN addgroup -g 1000 alfis && \
    adduser -S -u 1000 -G alfis -h "$ALFIS_HOME" -D alfis && \
    mkdir -p "$ALFIS_HOME" && \
    chown -R alfis:alfis "$ALFIS_HOME"

# Copy binary
COPY --from=builder /alfis /usr/bin/alfis

# Generate default config
RUN /usr/bin/alfis -g > /etc/alfis.conf && \
    chown alfis:alfis /etc/alfis.conf

EXPOSE ${srv_port}
EXPOSE ${dns_port}
EXPOSE ${dns_port}/udp

WORKDIR /var/lib/alfis
USER alfis

ENTRYPOINT ["/usr/bin/alfis"]
CMD ["-n", "-c", "/etc/alfis.conf"]
