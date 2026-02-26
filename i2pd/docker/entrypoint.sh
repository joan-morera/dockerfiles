#!/bin/sh

# Define paths
DATA_DIR="${DATA_DIR:-/home/i2pd/data}"
DEFAULT_CONFIG="/defaults/i2pd.conf"
DEFAULT_CERTS="/defaults/certificates"

# Bootstrap configuration if missing
if [ ! -f "$DATA_DIR/i2pd.conf" ]; then
    echo "Bootstrapping i2pd.conf..."
    cp "$DEFAULT_CONFIG" "$DATA_DIR/i2pd.conf"
fi

# Bootstrap certificates if missing
if [ ! -d "$DATA_DIR/certificates" ]; then
    echo "Bootstrapping certificates..."
    cp -r "$DEFAULT_CERTS" "$DATA_DIR/certificates"
fi

# Handle start delay
SLEEP_TIME="${START_DELAY:-0}"
if [ "$SLEEP_TIME" -gt 0 ]; then
    echo "Sleeping for $SLEEP_TIME seconds..."
    sleep "$SLEEP_TIME"
fi

# Execute i2pd
exec /usr/bin/i2pd --datadir="$DATA_DIR" "$@"
