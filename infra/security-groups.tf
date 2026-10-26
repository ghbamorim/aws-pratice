resource "aws_security_group" "app" {
  name        = "aws-pratice-app-sg"
  description = "Security group for the application"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "aws-pratice-app-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "app_outbound" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "database" {
  name        = "aws-pratice-db-sg"
  description = "Security group for PostgreSQL"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "aws-pratice-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "database_from_app" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80

  cidr_ipv4 = "0.0.0.0/0"

  description = "Allow HTTP for HTTPS certificate validation and redirects"
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app.id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  cidr_ipv4 = "0.0.0.0/0"

  description = "Allow HTTPS traffic"
}