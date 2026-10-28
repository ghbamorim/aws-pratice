
#!/usr/bin/env bash
set -Eeuo pipefail

REGION="us-east-2"
DB_IDENTIFIER="aws-pratice-postgres"
DB_NAME="app"
DB_USER="postgres"

API_REPOSITORY="aws-pratice-api"
FRONTEND_REPOSITORY="aws-pratice-frontend"

DOMAIN="aws-lab-ghbamorim.duckdns.org"
COMPOSE_FILE="/opt/aws-pratice/compose.prod.yaml"

IMAGE_TAG="${1:?Uso: deploy.sh IMAGE_TAG}"

export AWS_DEFAULT_REGION="$REGION"
export AWS_PAGER=""

log() {
    printf '[deploy] %s\n' "$*"
}

fail() {
    printf '[deploy] ERRO: %s\n' "$*" >&2
    exit 1
}

retry() {
    local attempts="$1"
    local interval="$2"
    shift 2

    local attempt

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if "$@"; then
            return 0
        fi

        if ((attempt == attempts)); then
            return 1
        fi

        log "Tentativa ${attempt}/${attempts} falhou. Aguardando ${interval}s..."
        sleep "$interval"
    done
}

command -v aws >/dev/null || fail "AWS CLI não encontrado"
command -v docker >/dev/null || fail "Docker não encontrado"
command -v python3 >/dev/null || fail "Python 3 não encontrado"
command -v curl >/dev/null || fail "curl não encontrado"

docker compose version >/dev/null ||
    fail "Docker Compose não encontrado"

[[ -f "$COMPOSE_FILE" ]] ||
    fail "Arquivo não encontrado: $COMPOSE_FILE"

log "Verificando identidade AWS..."

ACCOUNT_ID="$(
    aws sts get-caller-identity \
        --query Account \
        --output text
)"

[[ -n "$ACCOUNT_ID" && "$ACCOUNT_ID" != "None" ]] ||
    fail "Não foi possível identificar a conta AWS"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

log "Aguardando disponibilidade do RDS..."

retry 30 10 \
    aws rds wait db-instance-available \
        --db-instance-identifier "$DB_IDENTIFIER" ||
    fail "RDS não ficou disponível"

log "Consultando configuração do RDS..."

DB_ENDPOINT="$(
    aws rds describe-db-instances \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text
)"

DB_PORT="$(
    aws rds describe-db-instances \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --query 'DBInstances[0].Endpoint.Port' \
        --output text
)"

SECRET_ARN="$(
    aws rds describe-db-instances \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --query 'DBInstances[0].MasterUserSecret.SecretArn' \
        --output text
)"

[[ -n "$DB_ENDPOINT" && "$DB_ENDPOINT" != "None" ]] ||
    fail "Endpoint do RDS não encontrado"

[[ -n "$SECRET_ARN" && "$SECRET_ARN" != "None" ]] ||
    fail "Secret ARN do RDS não encontrado"

log "Recuperando credenciais do Secrets Manager..."

SECRET_JSON="$(
    aws secretsmanager get-secret-value \
        --secret-id "$SECRET_ARN" \
        --query SecretString \
        --output text
)"

[[ -n "$SECRET_JSON" && "$SECRET_JSON" != "None" ]] ||
    fail "Credenciais do RDS não encontradas"

# Codifica usuário e senha para uso seguro em uma URL PostgreSQL.
DATABASE_URL="$(
    SECRET_JSON="$SECRET_JSON" \
    DB_ENDPOINT="$DB_ENDPOINT" \
    DB_PORT="$DB_PORT" \
    DB_NAME="$DB_NAME" \
    DB_USER="$DB_USER" \
    python3 - <<'PY'
import json
import os
from urllib.parse import quote

secret = json.loads(os.environ["SECRET_JSON"])

username = quote(os.environ["DB_USER"], safe="")
password = quote(secret["password"], safe="")
host = os.environ["DB_ENDPOINT"]
port = os.environ["DB_PORT"]
database = os.environ["DB_NAME"]

print(
    f"postgresql+psycopg://{username}:{password}"
    f"@{host}:{port}/{database}"
)
PY
)"

unset SECRET_JSON

export DATABASE_URL
export ECR_REGISTRY
export IMAGE_TAG

log "Autenticando Docker no ECR..."

retry 5 10 \
    aws ecr get-login-password \
        --region "$REGION" \
        > /tmp/aws-pratice-ecr-password ||
    fail "Não foi possível obter token do ECR"

docker login \
    --username AWS \
    --password-stdin "$ECR_REGISTRY" \
    < /tmp/aws-pratice-ecr-password ||
    fail "Falha na autenticação no ECR"

rm -f /tmp/aws-pratice-ecr-password

log "Verificando imagens no ECR..."

for repository in "$API_REPOSITORY" "$FRONTEND_REPOSITORY"; do
    retry 12 10 \
        aws ecr describe-images \
            --repository-name "$repository" \
            --image-ids "imageTag=$IMAGE_TAG" \
            --region "$REGION" \
            >/dev/null ||
        fail "Imagem indisponível: ${repository}:${IMAGE_TAG}"
done

log "Baixando imagens..."

retry 5 10 \
    docker compose \
        -f "$COMPOSE_FILE" \
        pull ||
    fail "Falha ao baixar imagens"

log "Iniciando contêineres..."

docker compose \
    -f "$COMPOSE_FILE" \
    up -d \
    --remove-orphans ||
    fail "Falha ao iniciar contêineres"

log "Aguardando API..."

check_api() {
    docker compose \
        -f "$COMPOSE_FILE" \
        exec -T api \
        python -c \
        "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=5)" \
        >/dev/null 2>&1
}

retry 30 10 check_api ||
    fail "API não ficou saudável"

log "Aguardando certificado HTTPS..."

check_https() {
    curl \
        --fail \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 15 \
        --resolve "${DOMAIN}:443:127.0.0.1" \
        "https://${DOMAIN}/" \
        -o /dev/null
}

retry 30 10 check_https ||
    fail "HTTPS não ficou disponível"

log "Verificando estado dos contêineres..."

docker compose \
    -f "$COMPOSE_FILE" \
    ps

log "Deploy concluído com sucesso."
log "Aplicação: https://${DOMAIN}"
