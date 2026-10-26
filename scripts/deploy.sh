#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:?Image SHA required}"
ECR_REGISTRY="242627333067.dkr.ecr.us-east-2.amazonaws.com"
AWS_REGION="us-east-2"
APP_DIR="/opt/aws-pratice"

# Accept only full Git commit SHAs.
[[ "$IMAGE_TAG" =~ ^[a-f0-9]{40}$ ]] || {
  echo "Invalid image tag" >&2
  exit 1
}

mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Download the Compose configuration from the release commit.
curl -fsSL --retry 3 \
  "https://raw.githubusercontent.com/ghbamorim/aws-pratice/${IMAGE_TAG}/compose.prod.yaml" \
  -o compose.prod.yaml

# Retrieve the database password locally on EC2.
# Never print the password or DATABASE_URL.
export IMAGE_TAG ECR_REGISTRY AWS_REGION

python3 - <<'PY'
import os
import subprocess
from pathlib import Path
from urllib.parse import quote

password = subprocess.check_output(
    [
        "aws", "ssm", "get-parameter",
        "--name", "/pratice/database/password",
        "--with-decryption",
        "--region", os.environ["AWS_REGION"],
        "--query", "Parameter.Value",
        "--output", "text",
    ],
    text=True,
).rstrip("\n")

database_url = (
    "postgresql+psycopg://appuser:"
    + quote(password, safe="")
    + "@aws-pratice-db.cbwmwcm8yv8g.us-east-2.rds.amazonaws.com:5432/app"
)

env_path = Path(".env")
env_path.touch(mode=0o600, exist_ok=True)
env_path.chmod(0o600)
env_path.write_text(
    "ECR_REGISTRY=" + os.environ["ECR_REGISTRY"] + "\n"
    + "IMAGE_TAG=" + os.environ["IMAGE_TAG"] + "\n"
    + "DATABASE_URL='" + database_url + "'\n"
)
env_path.chmod(0o600)
PY

# Authenticate using the EC2 instance role.
aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Pull the exact images associated with the release.
docker compose --env-file .env -f compose.prod.yaml pull

# Apply database migrations before starting the application.
docker compose --env-file .env -f compose.prod.yaml \
  run --rm --no-deps api alembic upgrade head

# Start or update application containers.
docker compose --env-file .env -f compose.prod.yaml up -d \
  --remove-orphans

docker compose --env-file .env -f compose.prod.yaml ps
