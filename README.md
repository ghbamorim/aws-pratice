# Datadog Lab — Phase 1 (local development)

An observability practice application using React, FastAPI, PostgreSQL, and AWS Lambda logic exposed through a local HTTP adapter.

## Prerequisites

- Docker Engine / Docker Desktop with Docker Compose v2
- Available local ports: 5173, 8000, 9000, and 5432

## Run locally

```bash
docker compose up --build
```

- Frontend: http://localhost:5173
- API documentation: http://localhost:8000/docs
- Health check: http://localhost:8000/api/health

Create an order in the frontend, select **Process**, and try the fault injection controls.

## Controlled faults

- `GET /api/faults/latency`: adds a 2-second delay
- `GET /api/faults/error`: intentionally returns HTTP 500
- `GET /api/faults/slow-query`: runs `pg_sleep(2)` in PostgreSQL
- `POST /api/faults/memory`: allocates 5 MiB per call (40 MiB cap)
- `DELETE /api/faults/memory`: releases the allocated memory
- `POST /api/orders/{id}/process?fault=error`: local Lambda logic fails; the API returns HTTP 502
- `POST /api/orders/{id}/process?fault=timeout`: local Lambda waits 6 seconds; the API times out after 4 seconds (HTTP 504)

Fault injection endpoints are enabled only when `LAB_FAULTS_ENABLED=true`. **Never expose these endpoints publicly in production.** AWS deployment will require restricted access and isolated exercises.

## Logs and cleanup

```bash
docker compose logs -f api lambda-local db
docker compose down                 # Keep local database data
docker compose down -v              # Delete local database data
```

## Notes

- `lambda/handler.py` is independent of its local HTTP adapter (`local_server.py`) and can later be packaged as an AWS Lambda handler.
- `lambda-local` is **not** the official AWS Lambda runtime. It simulates HTTP invocation to test the business logic locally.
- Dependencies are pinned or constrained for this lab. Before production use, refresh dependencies, generate lockfiles, and check vulnerabilities.
- Datadog instrumentation, working Terraform infrastructure, and GitHub Actions deployment workflows are **not implemented yet**. They are planned for later phases.
