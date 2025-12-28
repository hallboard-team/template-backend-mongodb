#!/usr/bin/env bash
# Run from repo root: ./.devcontainer/docker/run-shared-mongo.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

: "${MONGO_VERSION:=7.0}"
: "${MONGO_PORT:=28001}"
: "${DB_USER:=mongo_user}"
: "${DB_PASSWORD:=mongo_password}"
: "${MONGO_CONTAINER_NAME:=shared-mongo}"
: "${MONGO_VOLUME_NAME:=shared-mongo-data}"
: "${MONGO_IMAGE:=ghcr.io/hallboard-team/tools:mongo-${MONGO_VERSION}}"
: "${MONGO_NETWORK_NAME:=shared-mongo-net}"

if ! docker network ls --format '{{.Name}}' | grep -qx "$MONGO_NETWORK_NAME"; then
  docker network create "$MONGO_NETWORK_NAME" >/dev/null
fi

if docker ps -a --format '{{.Names}}' | grep -qx "$MONGO_CONTAINER_NAME"; then
  docker start "$MONGO_CONTAINER_NAME" >/dev/null
  docker network connect --alias mongo "$MONGO_NETWORK_NAME" "$MONGO_CONTAINER_NAME" >/dev/null 2>&1 || true
  echo "Started existing Mongo container: $MONGO_CONTAINER_NAME (port $MONGO_PORT)"
  exit 0
fi

docker run -d \
  --name "$MONGO_CONTAINER_NAME" \
  --hostname mongo \
  --network "$MONGO_NETWORK_NAME" \
  --network-alias mongo \
  -p "${MONGO_PORT}:27017" \
  -e "MONGO_INITDB_ROOT_USERNAME=${DB_USER}" \
  -e "MONGO_INITDB_ROOT_PASSWORD=${DB_PASSWORD}" \
  -e "DB_USER=${DB_USER}" \
  -e "DB_PASSWORD=${DB_PASSWORD}" \
  -v "${MONGO_VOLUME_NAME}:/data/db" \
  "$MONGO_IMAGE" \
  bash -lc 'set -e
    if [ ! -f /data/db/mongo-keyfile ]; then
      head -c 32 /dev/urandom | base64 > /data/db/mongo-keyfile
    fi
    chmod 600 /data/db/mongo-keyfile
    chown 999:999 /data/db/mongo-keyfile
    if [ ! -f /data/db/.rs-initialized ]; then
      mongod --replSet rs0 --bind_ip_all &
      init_pid=$!

      until mongosh --quiet --eval "db.runCommand({ ping: 1 }).ok" | grep 1 >/dev/null; do
        sleep 1
      done

      if ! mongosh --quiet --eval "rs.status().ok" | grep 1 >/dev/null; then
        mongosh --quiet --eval "rs.initiate({_id:\"rs0\",members:[{_id:0,host:\"mongo:27017\"}]})"
      fi

      if ! mongosh --quiet --eval "db.getSiblingDB(\"admin\").getUser(\"$DB_USER\") ? 1 : 0" | grep 1 >/dev/null; then
        mongosh --quiet --eval "db.getSiblingDB(\"admin\").createUser({user:\"$DB_USER\",pwd:\"$DB_PASSWORD\",roles:[{role:\"root\",db:\"admin\"}]})"
      fi

      touch /data/db/.rs-initialized
      mongosh --quiet --eval "db.getSiblingDB(\"admin\").shutdownServer({force:true})" || true
      wait "$init_pid" || true
    fi

    exec mongod --replSet rs0 --bind_ip_all --keyFile /data/db/mongo-keyfile
  '

echo "Started new Mongo container: $MONGO_CONTAINER_NAME (port $MONGO_PORT)"
