
# PostgreSQL database for the Datadog lab
resource "aws_db_instance" "postgres" {
  identifier     = "aws-pratice-postgres"
  engine         = "postgres"
  instance_class = "db.t3.micro"

  db_name  = "awspratice"
  username = "postgres"

  manage_master_user_password = true

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false

  multi_az                     = false
  backup_retention_period      = 0
  performance_insights_enabled = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name      = "aws-pratice-postgres"
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

output "postgres_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "postgres_database" {
  value = aws_db_instance.postgres.db_name
}

output "postgres_secret_arn" {
  value = aws_db_instance.postgres.master_user_secret[0].secret_arn
}
