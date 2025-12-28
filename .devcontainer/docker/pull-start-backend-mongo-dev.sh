#!/bin/bash
# -----------------------------
# Pull & Start Docker Compose for .NET + MongoDB backend template
#
# Usage:
#   ./pull-start-backend-mongo-dev.sh [api_port] [dotnet_version] [db_user] [db_password] [db_name] [project_name]
#
# Examples:
#   ./pull-start-backend-mongo-dev.sh
#   ./pull-start-backend-mongo-dev.sh 5000
#   ./pull-start-backend-mongo-dev.sh 5000 9.0
#   ./pull-start-backend-mongo-dev.sh 5000 9.0 mongo_user mongo_password mydb myproject
# -----------------------------

set -euo pipefail
cd "$(dirname "$0")"

# -----------------------------
# Load .env file
# -----------------------------
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  . ./.env
  set +a
fi

# -----------------------------
# Ensure repo ownership matches current user
# -----------------------------
if [ "$(stat -c %u ..)" != "$(id -u)" ]; then
  echo "⚠ Repo at '$(cd .. && pwd)' is not owned by user $(id -un) (uid $(id -u))."
  echo "   This breaks devcontainers (container runs as current UID)."
  echo
  echo "   Fix it once:"
  echo "     sudo chown -R $(id -u):$(id -g) '$(cd .. && pwd)'"
  echo
  exit 1
fi

# -----------------------------
# Argument overrides
# -----------------------------
API_PORT="${1:-${API_PORT:-5000}}"
DOTNET_VERSION="${2:-${DOTNET_VERSION:-10.0}}"
DB_USER="${3:-${DB_USER:-backend_mongo_user}}"
DB_PASSWORD="${4:-${DB_PASSWORD:-backend_mongo_password}}"
DB_NAME="${5:-${DB_NAME:-backend_mongo_db}}"

COMPOSE_PROJECT_NAME="${6:-${COMPOSE_PROJECT_NAME:-${CONTAINER_NAME:-template_backend_mongo}}}"

IMAGE="ghcr.io/hallboard-team/dotnet:${DOTNET_VERSION}-sdk"
COMPOSE_FILE="docker-compose.backend-mongo.yml"

API_CONTAINER_NAME="${COMPOSE_PROJECT_NAME}-api-dev"

# -----------------------------
# Fix VS Code shared cache permissions
# -----------------------------
sudo rm -rf ~/.cache/vscode-server-shared
mkdir -p ~/.cache/vscode-server-shared/bin
chown -R 1000:1000 ~/.cache/vscode-server-shared

# -----------------------------
# Ensure .NET SDK dev image exists
# -----------------------------
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "🧱 Found dev image '$IMAGE' locally — skipping pull."
else
  echo "📥 Pulling dev image '$IMAGE' from GHCR..."
  if ! docker pull "$IMAGE"; then
    echo "❌ Failed to pull '$IMAGE'. Check GHCR authentication."
    exit 1
  fi
fi

# -----------------------------
# Port checks
# -----------------------------
if ss -tuln | grep -q ":${API_PORT} "; then
  echo "⚠ API port ${API_PORT} is already used."
  exit 1
fi

echo
echo "🚀 Starting backend-mongo template stack:"
echo "   Project:         ${COMPOSE_PROJECT_NAME}"
echo "   .NET SDK:        ${DOTNET_VERSION}"
echo "   API port:        ${API_PORT}"
echo "   DB user:         ${DB_USER}"
echo "   DB name:         ${DB_NAME}"
echo

# -----------------------------
# Start the stack
# -----------------------------
if COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT_NAME" \
   API_PORT="$API_PORT" \
   DOTNET_VERSION="$DOTNET_VERSION" \
   DB_USER="$DB_USER" \
   DB_PASSWORD="$DB_PASSWORD" \
   DB_NAME="$DB_NAME" \
   docker-compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" up -d; then

  if docker ps --filter "name=${API_CONTAINER_NAME}" --format '{{.Names}}' | grep -q "${API_CONTAINER_NAME}"; then
    echo "✅ API container '${API_CONTAINER_NAME}' running on port ${API_PORT}"
    echo "✅ MongoDB should be running in the shared container (see run-shared-mongo.sh)"
  else
    echo "❌ API container '${API_CONTAINER_NAME}' did not start even though compose succeeded."
    exit 1
  fi
else
  echo "❌ docker-compose failed."
  exit 1
fi
