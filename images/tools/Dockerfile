# Training workload image: the minimal Ubuntu 24.04 base plus the client tools
# the labs use. OpenShell only runs what the image contains, and the default
# image ships without curl, python3 or git.
FROM ubuntu:24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl wget git jq python3 python3-venv dnsutils netcat-openbsd \
 && rm -rf /var/lib/apt/lists/*

# ubuntu:24.04 already ships a non-root "ubuntu" user with UID 1000.
USER ubuntu
WORKDIR /home/ubuntu
