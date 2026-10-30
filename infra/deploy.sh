#!/bin/bash
set -euo pipefail
set +x

REGION="us-east-2"
APP_DIR="/opt/aws-pratice"

export ECR_REGISTRY="${1:?ECR registry obrigatorio}"
export IMAGE_TAG="${2:?Tag obrigatoria}"
DB_ENDPOINT="${3:?Endpoint RDS obrigatorio}"
SECRET_ARN="${4:?ARN do segredo obrigatorio}"

cd "$APP_DIR"

echo "Autenticando no ECR..."

aws ecr get-login-password \
  --region "$REGION" |
  docker login \
    --username AWS \
    --password-stdin "$ECR_REGISTRY"

echo "Consultando Secrets Manager..."

SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$REGION" \
  --query SecretString \
  --output text)

export SECRET
export DB_ENDPOINT

export DATABASE_URL=$(python3 - <<'PY'
import json
import os
from urllib.parse import quote

secret = json.loads(os.environ["SECRET"])

user = quote(secret["username"], safe="")
password = quote(secret["password"], safe="")
host = os.environ["DB_ENDPOINT"]

print(
    f"postgresql+psycopg://"
    f"{user}:{password}@{host}:5432/app"
)
PY
)

unset SECRET

echo "Atualizando containers..."

docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d

unset DATABASE_URL

echo "Deploy concluido: $IMAGE_TAG"
