#!/bin/bash
set -euxo pipefail

dnf install -y docker

systemctl enable --now docker

# Instala Docker Compose como plugin do Docker CLI
ARCH=$(uname -m)
mkdir -p /usr/local/lib/docker/cli-plugins

curl --fail --location --retry 5 \
  "https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-${ARCH}" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

docker --version
docker compose version