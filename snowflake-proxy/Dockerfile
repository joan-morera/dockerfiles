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
    tzdata \
    tor

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

# Create non-root user
RUN adduser -D -u 1000 -h /nonexistent -s /bin/false snowflake

# Stage 2: Final (Scratch)
FROM scratch
LABEL org.opencontainers.image.source="https://github.com/joan-morera/dockerfiles"
LABEL org.opencontainers.image.description="Snowflake Proxy"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="JoanMorera"

# Copy Certificates & Timezone Info
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy GeoIP Databases (installed from Alpine tor package)
COPY --from=builder /usr/share/tor/geoip /usr/share/tor/geoip
COPY --from=builder /usr/share/tor/geoip6 /usr/share/tor/geoip6

# Copy Snowflake Proxy Binary & User/Group files
COPY --from=builder /build/snowflake/proxy/proxy /bin/proxy
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

USER 1000:1000
ENTRYPOINT ["/bin/proxy"]
