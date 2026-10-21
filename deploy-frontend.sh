#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Informe a versão, por exemplo: v1.0.3}"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versão inválida: $VERSION"
  exit 1
fi

IMAGE="ghcr.io/ghbamorim/aws-pratice-frontend:$VERSION"
BASE="/var/www"
RELEASES="$BASE/aws-pratice-releases"
WEBROOT="$BASE/aws-pratice"
TARGET="$RELEASES/$VERSION"

echo "Baixando frontend $VERSION..."
docker pull "$IMAGE"

CONTAINER=$(docker create "$IMAGE")
STAGING=$(mktemp -d "$BASE/.aws-pratice-staging.XXXXXX")

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -rf "$STAGING"
}
trap cleanup EXIT

echo "Extraindo arquivos React..."
docker cp "$CONTAINER:/app/dist/." "$STAGING/"

test -f "$STAGING/index.html" || {
  echo "Erro: index.html não encontrado."
  exit 1
}

mkdir -p "$RELEASES"

if [[ -e "$TARGET" ]]; then
  echo "Erro: versão já instalada em $TARGET"
  exit 1
fi

mv "$STAGING" "$TARGET"

if [[ -L "$WEBROOT" ]]; then
  ln -s "$TARGET" "$BASE/.aws-pratice-next"
  mv -Tf "$BASE/.aws-pratice-next" "$WEBROOT"
else
  echo "Primeiro deploy: preservando o diretório atual."
  echo "A migração inicial para symlink será feita separadamente."
fi

echo "Frontend $VERSION preparado."