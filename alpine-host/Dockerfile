FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    wget \
    iputils \
    iproute2 \
    traceroute \
    nmap \
    tcpdump \
    iperf3 \
    openssh-client \
    bind-tools \
    busybox-extras \
    net-tools

# Keep shell alive when GNS3 opens a console
CMD ["/bin/bash"]
