resource "aws_security_group" "ec2" {
  name        = "aws-pratice-ec2-sg"
  description = "HTTP access to EC2"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "aws-pratice-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_outbound" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "rds" {
  name        = "aws-pratice-rds-sg"
  description = "PostgreSQL access from EC2 only"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "aws-pratice-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ec2.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}