#!/usr/bin/env bash
set -euo pipefail

export AWS_REGION="us-east-2"
export AWS_ACCOUNT_ID="242627333067"
export IMAGE_TAG="${IMAGE_TAG:-latest}"

APP_DIR="/opt/aws-pratice"

SECRET_ARN="${DB_SECRET_ARN:?DB_SECRET_ARN is required}"
DB_HOST="${DB_HOST:?DB_HOST is required}"

cd "$APP_DIR"

# Retrieve database credentials from AWS Secrets Manager.
SECRET_JSON="$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)"

export SECRET_JSON

# Build the SQLAlchemy connection URL using psycopg 3.
export DATABASE_URL="$(python3 - <<'PY'
import json
import os
from urllib.parse import quote

secret = json.loads(os.environ["SECRET_JSON"])

username = quote(secret["username"], safe="")
password = quote(secret["password"], safe="")
host = os.environ["DB_HOST"]

print(
    f"postgresql+psycopg://{username}:{password}@{host}:5432/app"
)
PY
)"

unset SECRET_JSON

# Authenticate Docker with Amazon ECR.
aws ecr get-login-password \
  --region "$AWS_REGION" |
  docker login \
    --username AWS \
    --password-stdin \
    "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Pull the release images and start the application.
docker compose pull
docker compose up -d --remove-orphans

unset DATABASE_URL

# Display the status of the containers.
docker compose ps
