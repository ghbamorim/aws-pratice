# Phase 2 — AWS infrastructure

Infrastructure will be implemented after the local application has been validated.

Planned scope:
- Private S3 bucket + CloudFront (HTTPS) for the React build
- EC2 running FastAPI in Docker, behind an HTTPS endpoint
- ECR repository for the API image
- RDS PostgreSQL in private subnets
- AWS Lambda for order processing
- IAM, security groups, logs, and configuration parameters
- GitHub Actions with AWS OIDC authentication and no static access keys

**Important:** CloudFront HTTPS for the frontend does not automatically provide HTTPS for the API. The API HTTPS origin must be configured explicitly in Phase 2 (for example, an ALB with ACM and an appropriate domain, or API routing through CloudFront).
