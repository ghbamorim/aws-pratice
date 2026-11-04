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
- AWS infrastructure lives in `infra/`; `.github/workflows/deploy.yml` builds the production images and deploys them over SSM.

## Datadog on AWS (US1)

Terraform manages the Datadog AWS integration, its read-only IAM role/external ID, and an API key secret. EC2 first boot installs Docker Single Step Instrumentation (SSI) for Python and runs one Agent container for host/container metrics, API traces, and container stdout/stderr logs. CloudWatch supplies EC2, EBS, RDS, Lambda, load balancer, and S3 metrics from `us-east-2`.

Use Terraform **1.10+**, the existing `terraform-lab` AWS profile, and API/application keys from **Organization Settings** on `datadoghq.com`. A scoped application key needs `aws_configuration_read` and `aws_configuration_edit`. Supply keys for apply and destroy:

```bash
# Hidden prompts keep keys out of shell history and git.
read -rsp 'Datadog API key: ' TF_VAR_datadog_api_key; echo
export TF_VAR_datadog_api_key
read -rsp 'Datadog application key: ' TF_VAR_datadog_app_key; echo
export TF_VAR_datadog_app_key

terraform -chdir=infra init
terraform -chdir=infra plan
terraform -chdir=infra apply
```

For an existing lab, first apply the separate `infra/bootstrap` stack with its administrator profile to grant management of the new Datadog role. Keep that bootstrap/state stack when rebuilding. `init` installs Datadog and updates the provider lock file.

After apply, publish a release or run **Deploy AWS** from an allowed release tag. Deployment waits for SSI and a healthy Agent before recreating containers. Terraform supplies the current RDS host/secret ARN, so destroy → apply → Actions deploy needs no script edits or Datadog keys in Actions. Generated secret names avoid deletion-window collisions. **Destroy deletes the database and ECR images.** User-data/key changes replace EC2; deploy again afterward.

Check `docker exec dd-agent agent status` through SSM, exercise `/api/faults/latency` and `/api/faults/error`, then check Infrastructure, APM, and Logs with `env:lab`. Service names are `aws-pratice-api` and `aws-pratice-frontend`; allow 10–15 minutes for AWS metrics. nginx provides container logs/metrics. Browser RUM, Lambda-side tracing/log forwarding, and RDS Database Monitoring are follow-up exercises.

Only the API key reaches EC2. Sensitive variables hide output but secret values remain in Terraform state and the Agent's Docker environment: protect remote state and EC2/SSM access. For bootstrap failures, inspect `/var/log/cloud-init-output.log` and `docker logs dd-agent`.
