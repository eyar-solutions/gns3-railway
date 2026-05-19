FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Base system tools + display stack + VNC + process manager
RUN apt-get update && apt-get install -y \
    software-properties-common \
    python3 python3-pip \
    dynamips vpcs ubridge docker.io \
    wget curl gettext-base iproute2 net-tools \
    supervisor \
    xvfb x11vnc novnc websockify \
    xfonts-base dbus-x11 \
    && add-apt-repository ppa:gns3/ppa \
    && apt-get update \
    && apt-get install -y gns3-server gns3-gui \
    && rm -rf /var/lib/apt/lists/*

# ubridge needs setuid root to manage network interfaces
RUN chmod u+s /usr/bin/ubridge 2>/dev/null || true

# GNS3 storage — mount a Railway volume here for persistence
RUN mkdir -p /gns3/images /gns3/projects /gns3/appliances /gns3/configs /etc/gns3

COPY configs/gns3_server.conf.tpl /etc/gns3/gns3_server.conf.tpl
COPY configs/gns3_gui.conf.tpl /etc/gns3/gns3_gui.conf.tpl
COPY configs/supervisord.conf /etc/supervisor/conf.d/gns3.conf
COPY configs/appliances/ /app/appliances/
COPY alpine-host/ /app/alpine-host/
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/pull-images.sh /usr/local/bin/pull-images.sh
COPY scripts/add-image.sh /usr/local/bin/add-image
RUN chmod +x /entrypoint.sh /usr/local/bin/pull-images.sh /usr/local/bin/add-image

# 6080 = noVNC web UI (primary, served over HTTP)
# 3080 = GNS3 REST API (used by add-image.sh)
EXPOSE 6080 3080

ENTRYPOINT ["/entrypoint.sh"]
