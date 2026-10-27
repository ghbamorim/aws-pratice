resource "aws_db_subnet_group" "postgres" {
  name = "aws-pratice-postgres-subnets"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "aws-pratice-postgres-subnets"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "aws-pratice-postgres"

  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 0
  storage_type          = "gp2"

  db_name  = "aws_pratice"
  username = "postgres"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 0
  copy_tags_to_snapshot   = false

  skip_final_snapshot = true
  deletion_protection = false

  storage_encrypted = true

  auto_minor_version_upgrade = false

  enabled_cloudwatch_logs_exports = []

  tags = {
    Name = "aws-pratice-postgres"
  }
}

output "rds_endpoint" {
  description = "PostgreSQL RDS endpoint"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "PostgreSQL RDS port"
  value       = aws_db_instance.postgres.port
}

output "rds_database" {
  description = "PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the database credentials"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}