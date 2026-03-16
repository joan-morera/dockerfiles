#
# Snowflake Proxy (from Source)
#
# Stage 1: Builder (Build & Fetch Dependencies)
#
FROM alpine:latest AS builder

# Install Build & Runtime Data Dependencies
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    git \
    go \
    wget

# Obtain geoip databases directly from the Tor Project git repository
RUN mkdir -p /usr/share/tor && \
    wget -q "https://gitlab.torproject.org/tpo/core/tor/-/raw/main/src/config/geoip" -O /usr/share/tor/geoip && \
    wget -q "https://gitlab.torproject.org/tpo/core/tor/-/raw/main/src/config/geoip6" -O /usr/share/tor/geoip6

# Arguments
ARG SNOWFLAKE_VERSION

# Build Snowflake Proxy
WORKDIR /build
RUN echo "[BUILD] Cloning Snowflake..." && \
    git clone -q https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake.git && \
    cd snowflake && \
    # Checkout specific commit if provided
    if [ -n "$SNOWFLAKE_VERSION" ] && [ "$SNOWFLAKE_VERSION" != "latest" ]; then \
        git checkout "$SNOWFLAKE_VERSION"; \
    fi && \
    cd proxy && \
    # Build Static Binary
    CGO_ENABLED=0 go build -o proxy -ldflags '-extldflags "-static" -w -s' .

# Stage 2: Final (Scratch)
FROM scratch
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="Snowflake Proxy"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="JoanMorera"

# Copy Certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Copy Timezone Info
# Alpine does not have zoneinfo by default unless tzdata is installed.
# But snowflake uses it if available. We'll skip if not strictly needed or copy if present.
# Original had it. In Alpine we'd need 'apk add tzdata' in builder.
RUN apk add --no-cache tzdata && cp -r /usr/share/zoneinfo /zoneinfo
# Correcting above line to be part of the builder stage if needed.
# Since I'm rewriting, I'll add tzdata to the builder apk add.

# Resetting builder part for the final copy
FROM alpine:latest AS builder-with-tz
RUN apk add --no-cache tzdata
# Wait, I can just add it to the first builder stage. Correcting.

FROM alpine:latest AS builder
RUN apk add --no-cache \
    build-base \
    ca-certificates \
    git \
    go \
    wget \
    tzdata

RUN mkdir -p /usr/share/tor && \
    wget -q "https://gitlab.torproject.org/tpo/core/tor/-/raw/main/src/config/geoip" -O /usr/share/tor/geoip && \
    wget -q "https://gitlab.torproject.org/tpo/core/tor/-/raw/main/src/config/geoip6" -O /usr/share/tor/geoip6

ARG SNOWFLAKE_VERSION
WORKDIR /build
RUN git clone -q https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake.git && \
    cd snowflake && \
    if [ -n "$SNOWFLAKE_VERSION" ] && [ "$SNOWFLAKE_VERSION" != "latest" ]; then \
        git checkout "$SNOWFLAKE_VERSION"; \
    fi && \
    cd proxy && \
    CGO_ENABLED=0 go build -o proxy -ldflags '-extldflags "-static" -w -s' .

# Create non-root user
RUN adduser -D -u 1000 -h /nonexistent -s /bin/false snowflake

FROM scratch
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="Snowflake Proxy"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="JoanMorera"

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /usr/share/tor/geoip /usr/share/tor/geoip
COPY --from=builder /usr/share/tor/geoip6 /usr/share/tor/geoip6
COPY --from=builder /build/snowflake/proxy/proxy /bin/proxy
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

USER 1000:1000
ENTRYPOINT ["/bin/proxy"]
