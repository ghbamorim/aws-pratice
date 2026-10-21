#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Informe a versão, por exemplo: v1.0.5}"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versão inválida: $VERSION"
  exit 1
fi

IMAGE="ghcr.io/ghbamorim/aws-pratice-frontend:$VERSION"

BASE="/var/www"
RELEASES="$BASE/aws-pratice-releases"
WEBROOT="$BASE/aws-pratice"
TARGET="$RELEASES/$VERSION"

HEALTH_URL="http://127.0.0.1/"
HEALTH_HOST="aws-lab-ghbamorim.duckdns.org"

CONTAINER=""
STAGING=""
PREVIOUS=""
SWITCHED=false
DEPLOY_SUCCESS=false

cleanup() {
  if [[ -n "$CONTAINER" ]]; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  fi

  if [[ -n "$STAGING" && -d "$STAGING" ]]; then
    rm -rf "$STAGING"
  fi

  if [[ "$SWITCHED" == true && "$DEPLOY_SUCCESS" != true ]]; then
    echo "Falha detectada. Executando rollback..."

    if [[ -n "$PREVIOUS" && -d "$PREVIOUS" ]]; then
      ln -sfn "$PREVIOUS" "$BASE/.aws-pratice-rollback"
      mv -Tf "$BASE/.aws-pratice-rollback" "$WEBROOT"
      echo "Rollback concluído: $PREVIOUS"
    else
      echo "ERRO: não foi possível restaurar a versão anterior."
    fi
  fi
}

trap cleanup EXIT

echo "Iniciando deploy do frontend $VERSION..."

if [[ ! -L "$WEBROOT" ]]; then
  echo "ERRO: $WEBROOT não é um link simbólico."
  exit 1
fi

PREVIOUS=$(readlink -f "$WEBROOT")

if [[ ! -f "$PREVIOUS/index.html" ]]; then
  echo "ERRO: versão anterior inválida."
  exit 1
fi

if [[ -e "$TARGET" ]]; then
  echo "ERRO: versão $VERSION já instalada."
  exit 1
fi

echo "Versão anterior: $PREVIOUS"

docker pull "$IMAGE"

CONTAINER=$(docker create "$IMAGE")
STAGING=$(mktemp -d "$BASE/.aws-pratice-staging.XXXXXX")

echo "Extraindo arquivos React..."
docker cp "$CONTAINER:/app/dist/." "$STAGING/"

if [[ ! -f "$STAGING/index.html" ]]; then
  echo "ERRO: index.html não encontrado."
  exit 1
fi

echo "Configurando permissões..."

find "$STAGING" -type d -exec chmod 755 {} \;
find "$STAGING" -type f -exec chmod 644 {} \;

mkdir -p "$RELEASES"
mv "$STAGING" "$TARGET"
STAGING=""

echo "Ativando frontend $VERSION..."

ln -s "$TARGET" "$BASE/.aws-pratice-next"
mv -Tf "$BASE/.aws-pratice-next" "$WEBROOT"

SWITCHED=true

echo "Verificando frontend..."

HEALTH_OK=false

for attempt in {1..10}; do
  if curl --fail --silent --show-error \
    --max-time 3 \
    -H "Host: $HEALTH_HOST" \
    "$HEALTH_URL" | grep -qi '<html'; then

    HEALTH_OK=true
    break
  fi

  echo "Tentativa $attempt/10..."
  sleep 2
done

if [[ "$HEALTH_OK" != true ]]; then
  echo "ERRO: frontend não passou na verificação."
  exit 1
fi

DEPLOY_SUCCESS=true

echo "Deploy do frontend $VERSION concluído."