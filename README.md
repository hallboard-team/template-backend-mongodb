# .NET + MongoDB Backend Template

Container-first development environment for a .NET API backed by a shared MongoDB container. All tooling (SDK, VS Code Server cache) is encapsulated inside Docker so you can focus on writing code inside `src/`.

## Prerequisites
- Docker 24+ with Compose plugin
- VS Code with the **Dev Containers** extension (or any editor + Docker CLI)
- Access to the Hallboard GHCR registry (`ghcr.io/hallboard-team`)

## Quick Start
1. **Clone this template** and add your solution under `src/` (for example `src/Mvp/Mvp.sln`).
2. **Ensure a shared MongoDB container is running**  
   - Run `./.devcontainer/docker/run-shared-mongo.sh` to start (or reuse) the shared Mongo container.
   - The dev container connects to an external Docker network named `shared-mongo-net` by default.
   - The Mongo container is reachable at `mongo:27017` on that network.
3. **Launch the dev container**  
   - VS Code: `Dev Containers: Reopen in Container` will bring up `.devcontainer/docker/docker-compose.backend-mongo.yml`.  
   - CLI: run `.devcontainer/docker/pull-start-backend-mongo-dev.sh` (see below) to pull the SDK image and start the stack.
4. Open the terminal inside the `api-mongo` container and run your usual `dotnet` commands.

The API container uses `ghcr.io/hallboard-team/dotnet:${DOTNET_VERSION}-sdk` so the SDK version stays in sync with your project.

## Running via helper script
```bash
cd .devcontainer/docker
./pull-start-backend-mongo-dev.sh [api_port] [dotnet_version] [db_user] \
  [db_password] [project_name]
```
The script:
- Ensures repo ownership matches your user (required for Dev Container UID mapping)
- Pulls the requested SDK image if missing
- Prepares the VS Code shared cache directory
- Boots the compose stack and verifies the API container is healthy

Stop everything with `docker compose -p template_backend_mongo down` (or the project name you chose).

## Environment & configuration
Create `.devcontainer/docker/.env` (optional) to override defaults used by both VS Code and the script.

| Variable | Default | Purpose |
|----------|---------|---------|
| `COMPOSE_PROJECT_NAME` | `template_backend_mongo` | Prefix for running containers, networks, and volumes; also used as the MongoDB database name |
| `DOTNET_VERSION` | `10.0` | SDK tag -> `ghcr.io/hallboard-team/dotnet:${DOTNET_VERSION}-sdk` |
| `API_PORT` | `5000` (VS Code exposes `5002`) | Host port forwarded to API container port `5000` |
| `MONGO_VERSION` | `7.0` | MongoDB image tag used by `run-shared-mongo.sh` |
| `MONGO_PORT` | `28000` | Host port for the shared MongoDB container |
| `MONGO_NETWORK_NAME` | `shared-mongo-net` | External Docker network that the API container joins |
| `DB_USER` | `mongo_user` | MongoDB root username |
| `DB_PASSWORD` | `mongo_password` | MongoDB root password |

> Inside the container the API listens on `http://0.0.0.0:5000`. Adjust `ASPNETCORE_URLS` in the compose file if you need HTTPS or additional bindings.

## Database Access
This template assumes MongoDB is provided by a shared container on the external network. Connect with any client using the connection string printed inside the API container (identical to `MongoDb__ConnectionString` in the compose file).
This project expects the API to run inside the dev container, so MongoDB settings are supplied via compose environment variables rather than `appsettings*.json`.

## Repository layout
- `src/` – place your solution(s) here; this folder is bind-mounted into the container at `/workspaces/app/src`
- `.devcontainer/` – compose file, helper script, and VS Code metadata for the Dev Container experience
- `.vscode/` – optional workspace settings to share among the team

## Next steps
- Initialize a new solution: `dotnet new webapi -o src/MyApi`
- Update the compose file if your API exposes extra ports or needs other services
- Add CI/CD workflows for building/publishing your API and container images

## Troubleshooting: Docker disk space
If your shared Mongo container exits with `No space left on device`, Docker's storage area (images/volumes/cache) is full. This is independent from your host disk free space.

Common fixes:
- Increase Docker's disk allocation (Docker Desktop) or ensure the Docker data root lives on a partition with enough space (Linux).
- Prune old images/containers occasionally when you hit the limit: `docker system prune -af` (removes unused images/containers/networks).
