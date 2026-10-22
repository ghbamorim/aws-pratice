# aws-pratice

A development and DevOps lab using **FastAPI**, **React + Vite**, **PostgreSQL**, and **Docker**, with a planned path toward CI/CD and AWS deployment.

> **Status:** Local environment setup is in progress. The frontend/Nginx instructions below describe the proposed configuration; create the corresponding files before running the full stack.

## Architecture

- **API:** FastAPI in its own Docker image, listening on internal port `8000`.
- **Frontend:** React built with Vite and served by **Nginx** in a separate image.
- **Database:** PostgreSQL 16 in a local container; a managed database may be used on AWS later.
- **Routing:** The browser accesses the frontend, and relative `/api` requests are proxied to FastAPI.
- **S3:** Intended for attachments. LocalStack is not required.

Separate API and frontend images allow independent builds, deployments, versioning, and rollbacks.

## Prerequisites

- Docker Desktop with Docker Compose
- Node.js and npm for running the frontend outside Docker
- Python and backend dependencies for running the API outside Docker

## Running locally

### Option 1: Full stack with Docker

After adding `frontend/Dockerfile`, `frontend/nginx.conf`, and the `frontend` service to `compose.yaml`:

```powershell
docker compose up -d --build
```

Open **http://localhost:8080**. Nginx serves the React application and forwards `/api` requests to `http://api:8000` over the Docker network.

The planned Compose setup has three services (`db`, `api`, and `frontend`) with ports bound to the local loopback interface:

| Service | Port mapping |
| --- | --- |
| PostgreSQL | `127.0.0.1:5432:5432` |
| FastAPI | `127.0.0.1:8001:8000` |
| Nginx | `127.0.0.1:8080:80` |

### Option 2: Database in Docker, API and frontend on the host

Start only PostgreSQL:

```powershell
docker compose up -d db
```

Run the Python API on your host with this database connection string:

```text
DATABASE_URL=postgresql+psycopg://app:app@localhost:5432/app
```

Make the API available on **port 8001**, which is the default Vite proxy target. Start the backend using the project's appropriate command.

Then, from the `frontend` directory:

```powershell
npm install
npm run dev
```

Open **http://localhost:5173**.

**Important:** Containers reach PostgreSQL through `db:5432`, whereas applications running on the host use `localhost:5432`. The Compose database service must publish `127.0.0.1:5432:5432` for host-based development.

## Frontend configuration

### `frontend/vite.config.ts`

The Vite proxy applies **only to the development server**, not to production builds:

```ts
import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    plugins: [react()],
    server: {
      host: "127.0.0.1",
      port: 5173,
      strictPort: true,
      proxy: {
        "/api": {
          target: env.API_PROXY_TARGET || "http://localhost:8001",
          changeOrigin: true,
        },
      },
    },
  };
});
```

Use relative URLs in the frontend, such as `fetch("/api/...")`, rather than hard-coding the API hostname. If Vite is later run inside a container, set `API_PROXY_TARGET` to an address reachable from that container.

### `frontend/Dockerfile` (to be added)

```dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

### `frontend/nginx.conf` (to be added)

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://api:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

The lack of a trailing slash in `proxy_pass http://api:8000` preserves the `/api` prefix. This configuration assumes the FastAPI routes use that prefix.

### `frontend/.dockerignore` (to be added)

```text
node_modules
dist
.git
.env*
```

## Pending Docker Compose changes

The initial Compose file contains only `db` and `api`. To support both development modes:

1. Publish the database port as `127.0.0.1:5432:5432`.
2. Keep the API's container database hostname set to `db`.
3. Add a `frontend` service with `build: ./frontend`, port mapping `127.0.0.1:8080:80`, and a dependency on `api`.
4. Test both `docker compose up -d --build` and `docker compose up -d db`.

The `app/app` database credentials are **for local development only** and must not be used in production.

## Roadmap

- [ ] Complete and test both local development modes
- [ ] Set up automated tests, linting, and builds with GitHub Actions (CI)
- [ ] Provision AWS resources using Terraform
- [ ] Publish versioned Docker images to a container registry
- [ ] Implement manually triggered release deployments
- [ ] Add health checks and rollback support
- [ ] Validate costs, access permissions, and observability

**Target AWS region:** `us-east-2` (Ohio). Keep costs low by validating the local environment before provisioning new AWS resources.

## Documentation maintenance

Update this README as features are implemented and verified. Mark roadmap items complete only after testing, and document the commands actually used.
