#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${DB_HOST:?DB_HOST is required}"
: "${SECRET_ARN:?SECRET_ARN is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"

cd "$(dirname "$0")"

# Retrieve database credentials from Secrets Manager.
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

# Build the database connection URL.
export SECRET_JSON

DATABASE_URL=$(python3 - <<'PY'
import json
import os
from urllib.parse import quote

secret = json.loads(os.environ["SECRET_JSON"])

username = quote(secret["username"], safe="")
password = quote(secret["password"], safe="")
host = os.environ["DB_HOST"]

print(f"postgresql+psycopg://{username}:{password}@{host}:5432/app")
PY
)

unset SECRET_JSON
export DATABASE_URL

# Authenticate with Amazon ECR.
aws ecr get-login-password --region "$AWS_REGION" |
  docker login \
    --username AWS \
    --password-stdin "$ECR_REGISTRY"

# Pull the application images.
docker compose -f docker-compose.prod.yml pull

# Start or update the containers.
docker compose -f docker-compose.prod.yml up -d --remove-orphans

unset DATABASE_URL

echo "Deployment completed successfully: $IMAGE_TAG"
