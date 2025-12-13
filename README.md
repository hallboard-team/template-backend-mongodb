# .NET + MongoDB Backend Template

Container-first development environment for a .NET API backed by MongoDB. All tooling (SDK, database, VS Code Server cache) is encapsulated inside Docker so you can focus on writing code inside `src/`.

## Prerequisites
- Docker 24+ with Compose plugin
- VS Code with the **Dev Containers** extension (or any editor + Docker CLI)
- Access to the Hallboard GHCR registry (`ghcr.io/hallboard-team`)

## Quick Start
1. **Clone this template** and add your solution under `src/` (for example `src/Mvp/Mvp.sln`).
2. **Launch the dev container**  
   - VS Code: `Dev Containers: Reopen in Container` will bring up `.devcontainer/docker/docker-compose.backend-mongo.yml`.  
   - CLI: run `.devcontainer/docker/pull-start-backend-mongo-dev.sh` (see below) to pull the SDK image and start the stack.
3. Open the terminal inside the `api-mongo` container and run your usual `dotnet` commands.

The API container uses `ghcr.io/hallboard-team/dotnet:${DOTNET_VERSION}-sdk` so the SDK version stays in sync with your project.

## Running via helper script
```bash
cd .devcontainer/docker
./pull-start-backend-mongo-dev.sh [api_port] [dotnet_version] [mongo_version] \
  [db_host_port] [db_user] [db_password] [db_name]
```
The script:
- Ensures repo ownership matches your user (required for Dev Container UID mapping)
- Pulls the requested SDK image if missing
- Prepares the VS Code shared cache directory
- Boots the compose stack and verifies the API + Mongo containers are healthy

Stop everything with `docker compose -p template_backend_mongo down` (or the project name you chose).

## Environment & configuration
Create `.devcontainer/docker/.env` (optional) to override defaults used by both VS Code and the script.

| Variable | Default | Purpose |
|----------|---------|---------|
| `CONTAINER_NAME` | `template_backend_mongo` | Compose project prefix and container naming |
| `DOTNET_VERSION` | `10.0` | SDK tag -> `ghcr.io/hallboard-team/dotnet:${DOTNET_VERSION}-sdk` |
| `MONGO_VERSION` | `7.0` | MongoDB image tag (`ghcr.io/hallboard-team/tools:mongo-${MONGO_VERSION}`) |
| `API_PORT` | `5000` (VS Code exposes `5002`) | Host port forwarded to API container port `5000` |
| `DB_HOST_PORT` | `27018` | Host port forwarded to MongoDB port `27017` |
| `DB_USER` | `backend_mongo_user` | MongoDB root username |
| `DB_PASSWORD` | `backend_mongo_password` | MongoDB root password |
| `DB_NAME` | `backend_mongo_db` | Default database created at startup |

> Inside the container the API listens on `http://0.0.0.0:5000`. Adjust `ASPNETCORE_URLS` in the compose file if you need HTTPS or additional bindings.

## Repository layout
- `src/` – place your solution(s) here; this folder is bind-mounted into the container at `/workspaces/app/src`
- `.devcontainer/` – compose file, helper script, and VS Code metadata for the Dev Container experience
- `.vscode/` – optional workspace settings to share among the team

## Next steps
- Initialize a new solution: `dotnet new webapi -o src/MyApi`
- Update the compose file if your API exposes extra ports or needs other services
- Add CI/CD workflows for building/publishing your API and container images
