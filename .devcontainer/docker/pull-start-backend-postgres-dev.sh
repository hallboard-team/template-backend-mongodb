#!/bin/bash
# -----------------------------
# Pull & Start Docker Compose for .NET + PostgreSQL backend template
#
# Usage:
#   ./pull-start-backend-postgres-dev.sh [api_port] [dotnet_version] [postgres_version] [db_host_port] [db_user] [db_password] [db_name]
#
# Examples:
#   ./pull-start-backend-postgres-dev.sh
#   ./pull-start-backend-postgres-dev.sh 5000
#   ./pull-start-backend-postgres-dev.sh 5000 9.0
#   ./pull-start-backend-postgres-dev.sh 5000 9.0 17 5434 user pass mydb
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
POSTGRES_VERSION="${3:-${POSTGRES_VERSION:-17}}"
DB_HOST_PORT="${4:-${DB_HOST_PORT:-5433}}"
DB_USER="${5:-${DB_USER:-backend_postgres_user}}"
DB_PASSWORD="${6:-${DB_PASSWORD:-backend_postgres_password}}"
DB_NAME="${7:-${DB_NAME:-backend_postgres_db}}"

CONTAINER_NAME="${CONTAINER_NAME:-template_backend_postgres}"

IMAGE="ghcr.io/hallboard-team/dotnet-v${DOTNET_VERSION}:latest"
COMPOSE_FILE="docker-compose.backend-postgres.yml"

API_CONTAINER_NAME="${CONTAINER_NAME}_api"

# -----------------------------
# Fix VS Code shared cache permissions
# -----------------------------
sudo rm -rf ~/.cache/vscode-server-shared
mkdir -p ~/.cache/vscode-server-shared/bin
chown -R 1000:1000 ~/.cache/vscode-server-shared

# -----------------------------
# Ensure .NET SDK dev image exists
# -----------------------------
if docker image exists "$IMAGE"; then
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

if ss -tuln | grep -q ":${DB_HOST_PORT} "; then
  echo "⚠ DB host port ${DB_HOST_PORT} is already used."
  exit 1
fi

echo
echo "🚀 Starting backend-postgres template stack:"
echo "   Project:         ${CONTAINER_NAME}"
echo "   .NET SDK:        ${DOTNET_VERSION}"
echo "   PostgreSQL:      ${POSTGRES_VERSION}"
echo "   API port:        ${API_PORT}"
echo "   DB host port:    ${DB_HOST_PORT}"
echo "   DB user:         ${DB_USER}"
echo "   DB name:         ${DB_NAME}"
echo

# -----------------------------
# Start the stack
# -----------------------------
if CONTAINER_NAME="$CONTAINER_NAME" \
   API_PORT="$API_PORT" \
   DOTNET_VERSION="$DOTNET_VERSION" \
   POSTGRES_VERSION="$POSTGRES_VERSION" \
   DB_HOST_PORT="$DB_HOST_PORT" \
   DB_USER="$DB_USER" \
   DB_PASSWORD="$DB_PASSWORD" \
   DB_NAME="$DB_NAME" \
   docker-compose -p "$CONTAINER_NAME" -f "$COMPOSE_FILE" up -d; then

  if docker ps --filter "name=${API_CONTAINER_NAME}" --format '{{.Names}}' | grep -q "${API_CONTAINER_NAME}"; then
    echo "✅ API container '${API_CONTAINER_NAME}' running on port ${API_PORT}"
    echo "✅ PostgreSQL running on host port ${DB_HOST_PORT}"
  else
    echo "❌ API container '${API_CONTAINER_NAME}' did not start even though compose succeeded."
    exit 1
  fi
else
  echo "❌ docker-compose failed."
  exit 1
fi
