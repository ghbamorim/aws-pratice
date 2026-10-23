resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-${var.environment}-db-subnets"
  subnet_ids = data.aws_subnets.public.ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnets"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_security_group" "postgres" {
  name        = "${var.project_name}-${var.environment}-postgres-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_app" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.app.id

  description = "Allow PostgreSQL connections from application EC2"
  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16.15"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name                     = "appdb"
  username                    = "appuser"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Project     = var.project_name
    Environment = var.environment
  }
}
