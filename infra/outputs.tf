output "deploy_config" {
  description = "Infrastructure configuration required by the deployment pipeline."

  value = {
    aws_region   = "us-east-2"
    ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-2.amazonaws.com"
    rds_host     = aws_db_instance.postgres.address
    secret_arn   = aws_db_instance.postgres.master_user_secret[0].secret_arn
    instance_id  = aws_instance.app.id
  }
}

output "cloudfront_url" {
  description = "Public HTTPS URL of the application."
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
}