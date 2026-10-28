resource "aws_db_subnet_group" "postgres" {
  name = "aws-pratice-postgres-subnets"

  subnet_ids = [
    aws_subnet.public.id,
    aws_subnet.database.id
  ]

  tags = {
    Name = "aws-pratice-postgres-subnets"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "aws-pratice-postgres"

  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "app"
  username = "postgres"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  auto_minor_version_upgrade = true

  tags = {
    Name = "aws-pratice-postgres"
  }
}