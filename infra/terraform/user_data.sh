#!/bin/bash
set -euo pipefail

# Install Docker Engine
dnf install -y docker
systemctl enable --now docker

# Install Docker Compose V2 plugin
COMPOSE_VERSION="v2.40.3"

mkdir -p /usr/local/lib/docker/cli-plugins

curl -fSL \
  "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verify installation
docker --version
docker compose version

# Configure 1 GiB swap
if ! swapon --show | grep -q .; then
  dd if=/dev/zero of=/swapfile bs=1M count=1024
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi