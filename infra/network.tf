data "aws_vpc" "default" {
  default = true
}

# Subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for the FastAPI EC2 instance
resource "aws_security_group" "api" {
  name        = "aws-pratice-api-sg"
  description = "Security group for FastAPI EC2"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name      = "aws-pratice-api-sg"
    ManagedBy = "Terraform"
  }
}

# Allow HTTP access to the API
resource "aws_vpc_security_group_ingress_rule" "api_http" {
  security_group_id = aws_security_group.api.id

  description    = "HTTP access to FastAPI"
  prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront.id
  from_port      = 80
  to_port        = 80
  ip_protocol    = "tcp"
}

# Allow outbound traffic from EC2 to the internet and AWS services
resource "aws_vpc_security_group_egress_rule" "api_outbound" {
  security_group_id = aws_security_group.api.id

  description = "Outbound traffic"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# Security group for PostgreSQL RDS
resource "aws_security_group" "database" {
  name        = "aws-pratice-db-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name      = "aws-pratice-db-sg"
    ManagedBy = "Terraform"
  }
}

# Allow PostgreSQL connections only from the FastAPI EC2 instance
resource "aws_vpc_security_group_ingress_rule" "database_from_api" {
  security_group_id = aws_security_group.database.id

  description                  = "PostgreSQL from FastAPI"
  referenced_security_group_id = aws_security_group.api.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}

# Security group for Lambda if it needs access to RDS
resource "aws_security_group" "lambda" {
  name        = "aws-pratice-lambda-sg"
  description = "Security group for Lambda"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name      = "aws-pratice-lambda-sg"
    ManagedBy = "Terraform"
  }
}

# Allow PostgreSQL connections from Lambda
resource "aws_vpc_security_group_ingress_rule" "database_from_lambda" {
  security_group_id = aws_security_group.database.id

  description                  = "PostgreSQL from Lambda"
  referenced_security_group_id = aws_security_group.lambda.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}

# Allow outbound traffic from Lambda
resource "aws_vpc_security_group_egress_rule" "lambda_outbound" {
  security_group_id = aws_security_group.lambda.id

  description = "Lambda outbound traffic"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# DB subnet group for PostgreSQL RDS
resource "aws_db_subnet_group" "database" {
  name       = "aws-pratice-postgres-subnets"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name      = "aws-pratice-postgres-subnets"
    ManagedBy = "Terraform"
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}