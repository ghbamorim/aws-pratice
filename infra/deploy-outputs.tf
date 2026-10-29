output "deploy_ec2_instance_id" {
  description = "EC2 instance ID used for application deployments"
  value       = aws_instance.app.id
}

output "deploy_db_host" {
  description = "Private RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
}

output "deploy_db_secret_arn" {
  description = "ARN of the RDS-managed database credentials secret"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "deploy_aws_region" {
  description = "AWS region used for application deployments"
  value       = "us-east-2"
}
