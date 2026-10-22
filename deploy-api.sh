
#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="${1:?Specify a version, for example: v1.0.1}"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: invalid version: $VERSION"
  exit 1
fi

PROJECT_DIR="/home/ec2-user/aws-pratice"
COMPOSE_FILE="$PROJECT_DIR/compose.prod.yaml"
IMAGE_REPO="ghcr.io/ghbamorim/aws-pratice-api"
HEALTH_URL="http://127.0.0.1:8001/health"

LOCK_FILE="${DEPLOY_LOCK_FILE:-/tmp/aws-pratice-api-deploy.lock}"

PREVIOUS_IMAGE=""
PREVIOUS_CONTAINER=""
ROLLBACK_IMAGE=""
NEW_IMAGE=""
DEPLOY_STARTED=false
DEPLOY_SUCCESS=false

exec 9>"$LOCK_FILE"
flock -n 9 || {
  echo "ERROR: another deployment is already in progress."
  exit 1
}

cd "$PROJECT_DIR"

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

health_check() {
  local expected_image="$1"
  local container_id
  local running_image

  for attempt in {1..30}; do
    container_id=$(compose ps -q api)

    if [[ -n "$container_id" ]]; then
      running_image=$(
        docker inspect --format '{{.Image}}' "$container_id"
      )

      if [[ "$running_image" == "$expected_image" ]] &&
         [[ "$(docker inspect \
           --format '{{.State.Running}}' \
           "$container_id")" == "true" ]] &&
         curl --fail --silent --show-error \
           --max-time 3 \
           --output /dev/null \
           "$HEALTH_URL"; then
        return 0
      fi
    fi

    echo "Attempt $attempt/30: API is not healthy yet."
    sleep 2
  done

  return 1
}

rollback() {
  echo "Restoring previous image..."

  export APP_VERSION="$ROLLBACK_IMAGE"

  compose up -d --no-build --no-deps \
    --force-recreate api

  health_check "$PREVIOUS_IMAGE"
}

cleanup() {
  local exit_code=$?

  trap - EXIT INT TERM

  if [[ "$DEPLOY_SUCCESS" != true &&
        "$DEPLOY_STARTED" == true ]]; then

    echo "Failure detected. Starting rollback..."

    if rollback; then
      echo "Rollback completed. Previous API is healthy."
    else
      echo "CRITICAL ERROR: rollback verification failed."
    fi

    exit_code=1
  fi

  exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Starting API deployment $VERSION..."

PREVIOUS_CONTAINER=$(compose ps -q api)

if [[ -z "$PREVIOUS_CONTAINER" ]]; then
  echo "ERROR: no API container is running."
  exit 1
fi

PREVIOUS_IMAGE=$(
  docker inspect \
    --format '{{.Image}}' \
    "$PREVIOUS_CONTAINER"
)

# Preserve the exact previous image under a local tag.
ROLLBACK_TAG="rollback-$(date +%s)-$$"
ROLLBACK_IMAGE="$IMAGE_REPO:$ROLLBACK_TAG"

docker tag "$PREVIOUS_IMAGE" "$ROLLBACK_IMAGE"

export APP_VERSION="$VERSION"

echo "Pulling image..."
compose pull api

NEW_IMAGE=$(
  docker image inspect \
    --format '{{.Id}}' \
    "$IMAGE_REPO:$VERSION"
)

echo "Running database migrations..."
compose run --rm --no-deps api alembic upgrade head

echo "Updating API container..."
DEPLOY_STARTED=true

compose up -d --no-build --no-deps \
  --force-recreate api

echo "Checking API health..."

if ! health_check "$NEW_IMAGE"; then
  echo "ERROR: API failed the health check."
  exit 1
fi

DEPLOY_SUCCESS=true

echo "API deployment $VERSION completed successfully."
