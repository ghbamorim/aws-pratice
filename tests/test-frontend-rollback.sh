
#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
BASE="$TEST_ROOT/www"
MOCK_BIN="$TEST_ROOT/bin"
VERSION="v9.9.9"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p \
  "$BASE/aws-pratice-releases/v1.0.4" \
  "$MOCK_BIN"

echo "Versão anterior" \
  > "$BASE/aws-pratice-releases/v1.0.4/index.html"

ln -s \
  "$BASE/aws-pratice-releases/v1.0.4" \
  "$BASE/aws-pratice"

# Simula os comandos Docker necessários ao deploy.
cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  pull)
    exit 0
    ;;
  create)
    echo "fake-container"
    ;;
  cp)
    DEST="${3%/}"
    mkdir -p "$DEST/assets"
    cat > "$DEST/index.html" <<'HTML'
<!doctype html>
<html>
  <head>
    <link rel="stylesheet" href="/assets/app.css">
  </head>
  <body>
    <script src="/assets/app.js"></script>
  </body>
</html>
HTML
    echo "body {}" > "$DEST/assets/app.css"
    echo "console.log('ok')" > "$DEST/assets/app.js"
    ;;
  rm)
    exit 0
    ;;
  *)
    echo "Docker mock: comando inesperado: $*" >&2
    exit 1
    ;;
esac
MOCK

# Simula falha em todas as verificações HTTP.
cat > "$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
exit 22
MOCK

chmod +x "$MOCK_BIN/docker" "$MOCK_BIN/curl"

# Simula o flock, que pode não existir no Git Bash do Windows.
# Este teste verifica rollback, não concorrência entre deploys.
cat > "$MOCK_BIN/flock" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK

chmod +x "$MOCK_BIN/flock"

echo "Executando deploy com falha simulada..."

set +e
OUTPUT=$(
  PATH="$MOCK_BIN:$PATH" \
  DEPLOY_BASE="$BASE" \
  DEPLOY_LOCK_FILE="$TEST_ROOT/deploy.lock" \
  HEALTH_URL="http://localhost/health-test" \
  bash "$PROJECT_ROOT/deploy-frontend.sh" "$VERSION" 2>&1
)
STATUS=$?
set -e

echo "$OUTPUT"

if [[ "$STATUS" -eq 0 ]]; then
  echo "ERRO: o deploy deveria ter falhado."
  exit 1
fi

ACTIVE="$(readlink -f "$BASE/aws-pratice")"
EXPECTED="$BASE/aws-pratice-releases/v1.0.4"

if [[ "$ACTIVE" != "$EXPECTED" ]]; then
  echo "ERRO: rollback não restaurou a versão anterior."
  echo "Atual: $ACTIVE"
  exit 1
fi

if [[ "$(cat "$BASE/aws-pratice/index.html")" != "Versão anterior" ]]; then
  echo "ERRO: conteúdo anterior não foi restaurado."
  exit 1
fi

if ! grep -q "Rollback concluído" <<< "$OUTPUT"; then
  echo "ERRO: mensagem de rollback não encontrada."
  exit 1
fi

echo
echo "TESTE PASSOU: falha detectada e versão anterior restaurada."
