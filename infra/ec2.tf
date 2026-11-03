
# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role assumed by the EC2 instance
resource "aws_iam_role" "ec2" {
  name = "aws-pratice-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

# Allow the EC2 instance to pull Docker images from ECR
resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Enable AWS Systems Manager
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for the EC2 IAM role
resource "aws_iam_instance_profile" "ec2" {
  name = "aws-pratice-ec2-profile"
  role = aws_iam_role.ec2.name
}

# Install Docker and Docker Compose on first boot
locals {
  ec2_user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y docker amazon-ssm-agent

    systemctl enable --now docker
    systemctl enable --now amazon-ssm-agent

    mkdir -p /usr/local/lib/docker/cli-plugins

    curl -fsSL \
      https://github.com/docker/compose/releases/download/v2.39.4/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose

    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    docker compose version
  EOF
}

# EC2 instance for the application
resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.ec2_public.id
  vpc_security_group_ids = [aws_security_group.api.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  associate_public_ip_address = true

  user_data                   = local.ec2_user_data
  user_data_replace_on_change = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name      = "aws-pratice-api"
    Project   = "aws-pratice"
    Role      = "api"
    ManagedBy = "Terraform"
  }

  depends_on = [
    aws_route_table_association.ec2_public,
    aws_iam_role_policy_attachment.ec2_ssm,
    aws_iam_role_policy_attachment.ec2_ecr
  ]
}

# Stable public IP address
resource "aws_eip" "api" {
  domain = "vpc"

  tags = {
    Name      = "aws-pratice-api-ip"
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

# Associate Elastic IP with EC2
resource "aws_eip_association" "api" {
  instance_id   = aws_instance.api.id
  allocation_id = aws_eip.api.id
}

output "api_public_ip" {
  description = "Public IP address of the application EC2 instance"
  value       = aws_eip.api.public_ip
}

output "api_instance_id" {
  description = "EC2 instance ID for Systems Manager access"
  value       = aws_instance.api.id
}

output "api_ecr_repository_url" {
  description = "ECR repository URL for the FastAPI backend"
  value       = aws_ecr_repository.fastapi.repository_url
}
