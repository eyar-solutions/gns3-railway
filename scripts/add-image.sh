#!/bin/bash
# add-image.sh — upload images to a live GNS3 server (local or Railway)
#
# Usage:
#   add-image.sh --ios   /path/to/c3725.bin   [options]
#   add-image.sh --docker frrouting/frr:v9.0  [options]
#   add-image.sh --list                        [options]
#
# Options:
#   --host    HOST   GNS3 server host (default: localhost)
#   --port    PORT   GNS3 server port (default: 3080)
#   --user    USER   GNS3 username    (default: $GNS3_USER or admin)
#   --pass    PASS   GNS3 password    (default: $GNS3_PASSWORD or admin)

set -e

# ── defaults ──────────────────────────────────────────────────────────────────
HOST="${GNS3_HOST:-localhost}"
PORT="${GNS3_PORT:-3080}"
USER="${GNS3_USER:-admin}"
PASS="${GNS3_PASSWORD:-admin}"
MODE=""
TARGET=""

usage() {
    cat <<EOF
Usage:
  add-image.sh --ios   /path/to/image.bin  [--host HOST] [--port PORT] [--user USER] [--pass PASS]
  add-image.sh --docker image:tag           [--host HOST] [--port PORT] [--user USER] [--pass PASS]
  add-image.sh --list                       [--host HOST] [--port PORT] [--user USER] [--pass PASS]
EOF
}

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ios)    MODE="ios";    TARGET="$2"; shift 2 ;;
        --docker) MODE="docker"; TARGET="$2"; shift 2 ;;
        --list)   MODE="list";               shift   ;;
        --host)   HOST="$2";                 shift 2 ;;
        --port)   PORT="$2";                 shift 2 ;;
        --user)   USER="$2";                 shift 2 ;;
        --pass)   PASS="$2";                 shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

BASE_URL="http://${HOST}:${PORT}/v2"
AUTH="${USER}:${PASS}"

# ── helpers ───────────────────────────────────────────────────────────────────
check_server() {
    if ! curl -sf -u "$AUTH" "${BASE_URL}/version" > /dev/null; then
        echo "ERROR: Cannot reach GNS3 at ${BASE_URL} — check host/port/credentials"
        exit 1
    fi
}

# ── modes ─────────────────────────────────────────────────────────────────────
do_list() {
    echo "=== Dynamips (IOS) images ==="
    curl -sf -u "$AUTH" "${BASE_URL}/compute/dynamips/images" \
        | python3 -c "
import sys, json
imgs = json.load(sys.stdin)
if not imgs:
    print('  (none)')
else:
    for i in imgs:
        print(f\"  {i['filename']}  ({i.get('filesize',0)//1024//1024} MB)\")
"

    echo ""
    echo "=== Docker images ==="
    curl -sf -u "$AUTH" "${BASE_URL}/compute/docker/images" \
        | python3 -c "
import sys, json
imgs = json.load(sys.stdin)
if not imgs:
    print('  (none)')
else:
    for i in imgs:
        print(f\"  {i.get('image','?')}\")
" 2>/dev/null || echo "  (Docker not available on this server)"
}

do_ios_upload() {
    local file="$TARGET"
    if [ ! -f "$file" ]; then
        echo "ERROR: File not found: $file"
        exit 1
    fi

    local filename
    filename=$(basename "$file")
    local size
    size=$(wc -c < "$file")
    echo "Uploading ${filename} ($(( size / 1024 / 1024 )) MB) to ${BASE_URL}..."

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "$AUTH" \
        -X POST \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@${file}" \
        "${BASE_URL}/compute/dynamips/images/upload/${filename}")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
        echo "OK: ${filename} uploaded successfully"
        echo ""
        echo "Next steps:"
        echo "  1. Open GNS3 GUI → Edit → Preferences → Dynamips → IOS Routers"
        echo "  2. Click 'New' and select: ${filename}"
        echo "  3. Run Idle-PC finder (right-click node → Idle-PC) to reduce CPU usage"
    else
        echo "ERROR: Upload failed (HTTP ${HTTP_CODE})"
        echo "Check that the file is a valid Cisco IOS .bin and credentials are correct"
        exit 1
    fi
}

do_docker_pull() {
    local image="$TARGET"
    echo "Requesting GNS3 server to pull Docker image: ${image}"

    HTTP_CODE=$(curl -s -o /tmp/docker_pull_resp.json -w "%{http_code}" \
        -u "$AUTH" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"image\": \"${image}\"}" \
        "${BASE_URL}/compute/docker/images")

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "OK: ${image} is available on the GNS3 server"
    elif [ "$HTTP_CODE" = "409" ]; then
        echo "OK: ${image} already exists on the server"
    else
        # GNS3 may not expose a direct pull endpoint — fall back to exec
        echo "API pull not supported (HTTP ${HTTP_CODE}), trying docker pull inside container..."
        fallback_docker_pull "$image"
    fi
}

fallback_docker_pull() {
    local image="$1"
    # Find the running GNS3 container and exec docker pull inside it
    local container
    container=$(docker ps --filter "ancestor=gns3-railway_gns3" --format "{{.ID}}" 2>/dev/null | head -1)
    if [ -z "$container" ]; then
        container=$(docker ps --filter "name=gns3" --format "{{.ID}}" 2>/dev/null | head -1)
    fi

    if [ -n "$container" ]; then
        echo "Executing docker pull inside container ${container}..."
        docker exec "$container" docker pull "$image" && echo "OK: ${image} pulled"
    else
        echo "ERROR: Could not find a running GNS3 container for fallback docker pull"
        echo "On Railway: SSH into the container and run: docker pull ${image}"
        exit 1
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────
if [ -z "$MODE" ]; then
    usage
    exit 1
fi

check_server

case "$MODE" in
    list)   do_list ;;
    ios)    do_ios_upload ;;
    docker) do_docker_pull ;;
esac
