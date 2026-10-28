#!/bin/bash
set -euxo pipefail

# Instala dependências
dnf install -y docker awscli-2 python3

# Inicia Docker
systemctl enable --now docker

# Instala Docker Compose
ARCH=$(uname -m)
mkdir -p /usr/local/lib/docker/cli-plugins

curl --fail --location --retry 5 \
  "https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-${ARCH}" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verifica instalações
docker --version
docker compose version
aws --version