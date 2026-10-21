#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Informe a versão, por exemplo: v1.0.1}"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versão inválida: $VERSION"
  exit 1
fi

cd /home/ec2-user/aws-pratice

export APP_VERSION="$VERSION"

docker compose -f compose.prod.yaml pull api

docker compose -f compose.prod.yaml run --rm api alembic upgrade head

docker compose -f compose.prod.yaml up -d --no-build api

echo "Aguardando a API ficar pronta..."

HEALTH_OK=false

for attempt in {1..30}; do
  if curl --fail --silent --show-error \
      --max-time 3 \
      http://127.0.0.1:8001/health; then
    HEALTH_OK=true
    break
  fi

  echo "Tentativa $attempt/30: API ainda não está pronta."
  sleep 2
done

if [[ "$HEALTH_OK" != true ]]; then
  echo "ERRO: API não ficou saudável."
  exit 1
fi

echo
echo "Deploy da API $VERSION concluído."