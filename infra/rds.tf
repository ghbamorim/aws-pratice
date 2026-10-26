resource "aws_db_subnet_group" "database" {
  name = "aws-pratice-db-subnet-group"

  subnet_ids = [
    "subnet-08ed8b9c3c956c50e",
    "subnet-020c1ad7b8c7865ab",
    "subnet-0135e6e8abe23ddd5"
  ]

  tags = {
    Name = "aws-pratice-db-subnet-group"
  }
}

resource "aws_db_instance" "database" {
  identifier = "aws-pratice-db"

  engine         = "postgres"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "app"
  username = "appuser"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]

  publicly_accessible        = false
  multi_az                   = false
  backup_retention_period    = 0
  skip_final_snapshot        = true
  deletion_protection        = false
  auto_minor_version_upgrade = false

  tags = {
    Name = "aws-pratice-db"
  }
}