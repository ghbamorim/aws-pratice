resource "aws_security_group" "ec2" {
  name        = "aws-pratice-ec2-sg"
  description = "HTTP access to application"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from CloudFront origin-facing network"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    prefix_list_ids = [
      data.aws_ec2_managed_prefix_list.cloudfront.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-pratice-ec2-sg"
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "rds" {
  name        = "aws-pratice-rds-sg"
  description = "PostgreSQL access from EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from application"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = {
    Name = "aws-pratice-rds-sg"
  }
}
