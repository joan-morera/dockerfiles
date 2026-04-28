# Shatari Backend (Data Collector)
FROM node:22-alpine

# Install git and other dependencies if needed
RUN apk add --no-cache git bash

WORKDIR /app

# Arguments for version tracking
ARG SHATARI_VERSION=master

# Clone and install
RUN git clone https://github.com/erorus/shatari.git . && \
    git checkout ${SHATARI_VERSION} && \
    npm install

# Prepare data directory
RUN mkdir -p /data/realms /data/results

# Default environment variables (should be overridden at runtime)
ENV BATTLE_NET_KEY="" \
    BATTLE_NET_SECRET="" \
    ALIVENESS_PINGBACK="" \
    REALM_PINGBACK=""

# Entrypoint script to run main.js continuously
# The script exits if another instance is running, so we just loop it.
COPY <<EOF /entrypoint.sh
#!/bin/bash
while true; do
    echo "[$(date)] Starting Shatari worker..."
    node src/main.js
    echo "[$(date)] Shatari worker exited. Restarting in 60 seconds..."
    sleep 60
done
EOF

RUN chmod +x /entrypoint.sh

# The backend writes data to its own parent directory and subfolders usually.
# We will use symlinks or configure the app to write to /data.
# Based on src/main.js, it uses Path.resolve(__dirname, '..', ...)
# So if it's in /app/src, it writes to /app/...
# We can symlink /app/realms to /data/realms etc.
RUN ln -s /data/realms /app/realms && \
    ln -s /data/data /app/data

ENTRYPOINT ["/entrypoint.sh"]

