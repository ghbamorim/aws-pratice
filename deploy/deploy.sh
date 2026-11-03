#!/usr/bin/env bash
set -Eeuo pipefail

AWS_REGION="us-east-2"
AWS_ACCOUNT_ID="242627333067"

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

SECRET_ARN="arn:aws:secretsmanager:us-east-2:242627333067:secret:rds!db-41981a69-430c-44c6-969e-f98f822293ca-gRWvxz"
DB_HOST="aws-pratice-postgres.cbwmwcm8yv8g.us-east-2.rds.amazonaws.com"
DB_NAME="awspratice"

DEPLOY_DIR="/opt/aws-pratice"
COMPOSE_FILE="${DEPLOY_DIR}/compose.prod.yml"

echo "Starting deployment..."

cd "$DEPLOY_DIR"

# Check required tools
command -v aws >/dev/null
command -v docker >/dev/null
command -v python3 >/dev/null
docker compose version >/dev/null

# Retrieve database credentials from Secrets Manager
echo "Retrieving database credentials..."

SECRET_JSON="$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)"

# Build the database URL without writing credentials to disk
export SECRET_JSON DB_HOST DB_NAME

DATABASE_URL="$(python3 - <<'PY'
import json
import os
from urllib.parse import quote

secret = json.loads(os.environ["SECRET_JSON"])

username = quote(secret["username"], safe="")
password = quote(secret["password"], safe="")
host = os.environ["DB_HOST"]
database = os.environ["DB_NAME"]

print(
    f"postgresql+psycopg://{username}:{password}"
    f"@{host}:5432/{database}"
)
PY
)"

unset SECRET_JSON
export DATABASE_URL

# Authenticate Docker with Amazon ECR
echo "Authenticating with Amazon ECR..."

aws ecr get-login-password --region "$AWS_REGION" |
  docker login \
    --username AWS \
    --password-stdin "$ECR_REGISTRY"

# Download the latest application images
echo "Pulling Docker images..."

docker compose \
  -f "$COMPOSE_FILE" \
  pull

# Start or update the application
echo "Starting containers..."

docker compose \
  -f "$COMPOSE_FILE" \
  up -d \
  --remove-orphans \
  --force-recreate

# Remove credentials from the shell environment
unset DATABASE_URL

# Remove unused Docker images
echo "Cleaning up unused images..."

docker image prune -f

# Show running containers
docker compose \
  -f "$COMPOSE_FILE" \
  ps

echo "Deployment completed successfully."
