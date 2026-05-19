#!/bin/bash
# Pre-pull all Docker appliance images so GNS3 can use them instantly.
# Called from entrypoint on startup (runs in background).

set -e

IMAGES=(
    "frrouting/frr:latest"
    "openwrtorg/rootfs:x86-64-23.05.3"
    "gns3/openvswitch:latest"
)

for image in "${IMAGES[@]}"; do
    if docker image inspect "$image" &>/dev/null 2>&1; then
        echo "[pull-images] Already present: $image"
    else
        echo "[pull-images] Pulling: $image"
        docker pull "$image" && echo "[pull-images] Done: $image" || echo "[pull-images] Failed: $image"
    fi
done

# Build the custom Alpine host image if not already built
if ! docker image inspect gns3-railway/alpine-host:latest &>/dev/null 2>&1; then
    echo "[pull-images] Building gns3-railway/alpine-host..."
    docker build -t gns3-railway/alpine-host:latest /app/alpine-host/
    echo "[pull-images] Alpine host image ready"
fi

echo "[pull-images] All images ready"
