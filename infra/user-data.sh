#!/bin/bash
set -euxo pipefail

dnf install -y docker awscli-2 python3

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
aws --version

# Script de atualização do DuckDNS
cat > /usr/local/bin/update-duckdns.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail

REGION="us-east-2"
DOMAIN="aws-lab-ghbamorim"
SECRET_ID="aws-pratice-duckdns-token"

# Obtém token IMDSv2
METADATA_TOKEN=$(curl --fail --silent --show-error \
  --retry 5 --connect-timeout 5 --max-time 15 \
  -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)

# Descobre o IP público atual
PUBLIC_IP=$(curl --fail --silent --show-error \
  --retry 5 --connect-timeout 5 --max-time 15 \
  -H "X-aws-ec2-metadata-token: ${METADATA_TOKEN}" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

# Recupera o segredo sem gravá-lo em arquivo
DUCKDNS_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$REGION" \
  --query SecretString \
  --output text)

# Envia o IP ao DuckDNS
RESPONSE=$(curl --fail --silent --show-error \
  --retry 5 --connect-timeout 5 --max-time 20 \
  --get "https://www.duckdns.org/update" \
  --data-urlencode "domains=${DOMAIN}" \
  --data-urlencode "token=${DUCKDNS_TOKEN}" \
  --data-urlencode "ip=${PUBLIC_IP}")

if [[ "$RESPONSE" != "OK" ]]; then
  echo "Falha ao atualizar DuckDNS: $RESPONSE" >&2
  exit 1
fi

echo "DuckDNS atualizado: ${DOMAIN}.duckdns.org -> ${PUBLIC_IP}"
SCRIPT

chmod 700 /usr/local/bin/update-duckdns.sh

# Serviço de atualização
cat > /etc/systemd/system/duckdns-update.service <<'SERVICE'
[Unit]
Description=Atualiza IP público no DuckDNS
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-duckdns.sh
TimeoutStartSec=180
SERVICE

# Timer para inicialização e atualização periódica
cat > /etc/systemd/system/duckdns-update.timer <<'TIMER'
[Unit]
Description=Atualização periódica do DuckDNS

[Timer]
OnBootSec=30s
OnUnitInactiveSec=5min
AccuracySec=10s
Persistent=true
Unit=duckdns-update.service

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now duckdns-update.timer

# Executa a primeira atualização durante a inicialização
systemctl start duckdns-update.service
