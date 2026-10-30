#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y docker

systemctl enable --now docker

usermod -aG docker ec2-user

COMPOSE_VERSION="v2.40.3"

mkdir -p /usr/local/lib/docker/cli-plugins

curl -fSL \
  "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose