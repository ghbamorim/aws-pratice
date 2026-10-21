
#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="${1:?Informe a versão, por exemplo: v1.0.5}"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versão inválida: $VERSION"
  exit 1
fi

IMAGE="ghcr.io/ghbamorim/aws-pratice-frontend:$VERSION"

BASE="${DEPLOY_BASE:-/var/www}"
RELEASES="$BASE/aws-pratice-releases"
WEBROOT="$BASE/aws-pratice"
TARGET="$RELEASES/$VERSION"

HEALTH_URL="${HEALTH_URL:-https://aws-lab-ghbamorim.duckdns.org/}"

CONTAINER=""
STAGING=""
PREVIOUS=""
SWITCH_STARTED=false
DEPLOY_SUCCESS=false

# Impede dois deploys simultâneos.
exec 9>/var/lock/aws-pratice-frontend.lock
flock -n 9 || {
  echo "ERRO: já existe um deploy do frontend em andamento."
  exit 1
}

cleanup() {
  local exit_code=$?

  trap - EXIT INT TERM

  if [[ "$DEPLOY_SUCCESS" != true && "$SWITCH_STARTED" == true ]]; then
    echo "Falha detectada. Verificando necessidade de rollback..."

    if [[ -n "$PREVIOUS" && -f "$PREVIOUS/index.html" ]]; then
      if [[ "$(readlink -f "$WEBROOT" 2>/dev/null || true)" != "$PREVIOUS" ]]; then
        echo "Restaurando versão anterior: $PREVIOUS"

        local rollback_link
        rollback_link=$(mktemp -u "$BASE/.aws-pratice-rollback.XXXXXX")

        if ln -s "$PREVIOUS" "$rollback_link" &&
           mv -Tf "$rollback_link" "$WEBROOT"; then
          echo "Rollback concluído."
        else
          echo "ERRO CRÍTICO: rollback falhou."
          rm -f "$rollback_link"
          exit_code=1
        fi
      fi
    else
      echo "ERRO CRÍTICO: versão anterior indisponível."
      exit_code=1
    fi
  fi

  if [[ -n "$CONTAINER" ]]; then
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  fi

  if [[ -n "$STAGING" && -d "$STAGING" ]]; then
    rm -rf "$STAGING"
  fi

  if [[ "$DEPLOY_SUCCESS" != true ]]; then
    exit_code=1
  fi

  exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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

if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  echo "ERRO: versão $VERSION já instalada."
  exit 1
fi

echo "Versão anterior: $PREVIOUS"

docker pull "$IMAGE"

CONTAINER=$(docker create "$IMAGE")
STAGING=$(mktemp -d "$BASE/.aws-pratice-staging.XXXXXX")

echo "Extraindo arquivos React..."
docker cp "$CONTAINER:/app/dist/." "$STAGING/"

echo "Validando arquivos compilados..."

test -s "$STAGING/index.html" || {
  echo "ERRO: index.html ausente ou vazio."
  exit 1
}

# Confere os recursos locais referenciados pelo index.html.
python3 - "$STAGING" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
html = (root / "index.html").read_text(encoding="utf-8")

class Assets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.paths = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "script" and attrs.get("src"):
            self.paths.append(attrs["src"])
        if tag == "link" and attrs.get("rel") == "stylesheet":
            if attrs.get("href"):
                self.paths.append(attrs["href"])

parser = Assets()
parser.feed(html)

if not parser.paths:
    raise SystemExit("ERRO: nenhum JS/CSS referenciado no index.html.")

for path in parser.paths:
    if not path.startswith("/") or path.startswith("//"):
        raise SystemExit(f"ERRO: caminho de asset inesperado: {path}")

    asset = (root / path.lstrip("/")).resolve()

    if not asset.is_relative_to(root) or not asset.is_file():
        raise SystemExit(f"ERRO: asset não encontrado: {path}")

    if asset.stat().st_size == 0:
        raise SystemExit(f"ERRO: asset vazio: {path}")

    print(f"Asset OK: {path}")
PY

echo "Configurando permissões..."

find "$STAGING" -type d -exec chmod 755 {} \;
find "$STAGING" -type f -exec chmod 644 {} \;

mkdir -p "$RELEASES"
mv "$STAGING" "$TARGET"
STAGING=""

echo "Ativando frontend $VERSION..."

NEXT_LINK=$(mktemp -u "$BASE/.aws-pratice-next.XXXXXX")
ln -s "$TARGET" "$NEXT_LINK"

# A partir daqui, qualquer falha exige verificar o link ativo.
SWITCH_STARTED=true
mv -Tf "$NEXT_LINK" "$WEBROOT"

echo "Verificando frontend pelo Nginx..."

HEALTH_OK=false

for attempt in {1..10}; do
  RESPONSE=$(mktemp)

  if curl --fail --silent --show-error \
      --max-time 5 \
      --output "$RESPONSE" \
      "$HEALTH_URL" &&
      cmp -s "$RESPONSE" "$TARGET/index.html"; then
    HEALTH_OK=true
    rm -f "$RESPONSE"
    break
  fi

  rm -f "$RESPONSE"
  echo "Tentativa $attempt/10: frontend ainda não validado."
  sleep 2
done

if [[ "$HEALTH_OK" != true ]]; then
  echo "ERRO: frontend não passou na verificação."
  exit 1
fi

DEPLOY_SUCCESS=true

echo "Deploy do frontend $VERSION concluído."
