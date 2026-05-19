#!/bin/bash
set -e

# Defaults (override via Railway env vars)
export GNS3_USER="${GNS3_USER:-admin}"
export GNS3_PASSWORD="${GNS3_PASSWORD:-admin}"
export GNS3_AUTH="${GNS3_AUTH:-True}"

# Ensure persistent storage dirs exist (first boot on a fresh volume)
mkdir -p /gns3/images/QEMU \
         /gns3/images/IOS \
         /gns3/images/IOSv \
         /gns3/images/IOU \
         /gns3/projects \
         /gns3/appliances \
         /gns3/configs

# Render server config from template
envsubst < /etc/gns3/gns3_server.conf.tpl > /etc/gns3/gns3_server.conf

# Render GUI config so it connects to our server with the right credentials
GNS3_VERSION=$(gns3server --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "2.2")
mkdir -p "/root/.config/GNS3/${GNS3_VERSION}"
envsubst < /etc/gns3/gns3_gui.conf.tpl > "/root/.config/GNS3/${GNS3_VERSION}/gns3_gui.conf"

# Seed appliances into the persistent volume on first boot (never overwrite)
for appliance in /app/appliances/*.gns3a; do
    dest="/gns3/appliances/$(basename "$appliance")"
    if [ ! -f "$dest" ]; then
        cp "$appliance" "$dest"
        echo "[entrypoint] Installed appliance: $(basename "$appliance")"
    fi
done

# Start Docker daemon in background if the socket isn't already there
# (needed for Docker appliances inside GNS3)
if [ -S /var/run/docker.sock ]; then
    echo "[entrypoint] Using host Docker socket"
else
    echo "[entrypoint] Starting Docker daemon..."
    dockerd --host=unix:///var/run/docker.sock &>/var/log/dockerd.log &
    # Wait until Docker is ready
    timeout=30
    until docker info &>/dev/null 2>&1; do
        sleep 1
        timeout=$((timeout - 1))
        if [ "$timeout" -le 0 ]; then
            echo "[entrypoint] Warning: Docker daemon not ready — Docker appliances won't work"
            break
        fi
    done
    # Pull appliance images in background so GNS3 starts immediately
    pull-images.sh &>/var/log/pull-images.log &
fi

# Required by Qt/D-Bus for the GUI
mkdir -p /tmp/runtime-root
chmod 700 /tmp/runtime-root

echo "[entrypoint] Starting all services (noVNC on :6080, GNS3 API on :3080)..."
exec supervisord -c /etc/supervisor/conf.d/gns3.conf
