resource "aws_security_group" "ec2" {
  name        = "aws-pratice-ec2-sg"
  description = "Security group for application EC2"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "aws-pratice-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  security_group_id = aws_security_group.ec2.id

  description = "Allow HTTP from CloudFront origin-facing servers"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront.id
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_egress_rule" "ec2_outbound" {
  security_group_id = aws_security_group.ec2.id

  description = "Allow outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_security_group" "rds" {
  name        = "aws-pratice-rds-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "aws-pratice-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgres" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Allow PostgreSQL from application EC2"
  referenced_security_group_id = aws_security_group.ec2.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}
