resource "aws_db_subnet_group" "main" {
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

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "app"
  username = "postgres"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false

  storage_encrypted   = true
  deletion_protection = false
  skip_final_snapshot = true
}