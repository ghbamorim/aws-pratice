
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

# Install Docker, Docker Compose, and Datadog before the first application deploy.
locals {
  ec2_user_data = <<-EOF
    #!/bin/bash
    # Avoid shell tracing: the Datadog API key must not enter cloud-init logs.
    set -euo pipefail

    dnf update -y
    dnf install -y docker amazon-ssm-agent awscli2 python3

    systemctl enable --now docker
    systemctl enable --now amazon-ssm-agent

    mkdir -p /usr/local/lib/docker/cli-plugins

    curl -fsSL \
      https://github.com/docker/compose/releases/download/v2.39.4/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose

    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    docker compose version

    # These non-secret settings follow the new RDS resources after destroy/apply.
    cat > /etc/aws-pratice-deploy.env <<'CONFIG'
    SECRET_ARN='${aws_db_instance.postgres.master_user_secret[0].secret_arn}'
    DB_HOST='${aws_db_instance.postgres.address}'
    DB_NAME='${aws_db_instance.postgres.db_name}'
    CONFIG
    chmod 600 /etc/aws-pratice-deploy.env

    # Read only the API key at runtime; Terraform user_data contains its ARN only.
    # Secret version ${aws_secretsmanager_secret_version.datadog_api_key.version_id} triggers replacement on key rotation.
    export AWS_RETRY_MODE=standard AWS_MAX_ATTEMPTS=10
    for attempt in $(seq 1 30); do
      if DD_API_KEY=$(aws secretsmanager get-secret-value \
        --region us-east-2 \
        --secret-id '${aws_secretsmanager_secret.datadog_api_key.arn}' \
        --query SecretString --output text); then
        break
      fi
      sleep 2
    done
    test -n "$DD_API_KEY" && test "$DD_API_KEY" != None
    export DD_API_KEY
    trap 'unset DD_API_KEY' EXIT

    # SSI hooks Docker container creation and injects the Python tracer.
    # Install no host Agent: this lab runs exactly one Agent, inside Docker.
    curl -fsSL --retry 5 \
      https://install.datadoghq.com/scripts/install_script_agent7.sh \
      -o /tmp/install_script_agent7.sh
    DD_SITE=datadoghq.com \
      DD_APM_INSTRUMENTATION_ENABLED=docker \
      DD_APM_INSTRUMENTATION_LIBRARIES=python:3 \
      DD_NO_AGENT_INSTALL=true \
      bash /tmp/install_script_agent7.sh
    rm /tmp/install_script_agent7.sh

    # SSI sends traces through these shared Unix sockets; no public APM ports.
    mkdir -p /var/run/datadog
    docker run -d --name dd-agent --restart unless-stopped \
      -e DD_API_KEY \
      -e DD_SITE=datadoghq.com \
      -e DD_ENV=lab \
      -e DD_APM_ENABLED=true \
      -e DD_APM_NON_LOCAL_TRAFFIC=true \
      -e DD_APM_RECEIVER_SOCKET=/var/run/datadog/apm.socket \
      -e DD_DOGSTATSD_SOCKET=/var/run/datadog/dsd.socket \
      -e DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true \
      -e DD_LOGS_ENABLED=true \
      -e DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true \
      -v /var/run/datadog:/var/run/datadog \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v /proc:/host/proc:ro \
      -v /sys/fs/cgroup:/host/sys/fs/cgroup:ro \
      -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
      registry.datadoghq.com/agent:7
    unset DD_API_KEY

    # Deploy checks this marker so a failed bootstrap cannot silently skip APM.
    for attempt in $(seq 1 60); do
      if docker exec dd-agent agent health >/dev/null 2>&1; then
        install -d /var/lib/aws-pratice
        touch /var/lib/aws-pratice/observability-ready
        exit 0
      fi
      sleep 5
    done
    echo "Datadog Agent did not become healthy" >&2
    exit 1
  EOF
}

# EC2 instance for the application
resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.ec2_public.id
  vpc_security_group_ids = [aws_security_group.api.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  associate_public_ip_address = true

  user_data                   = local.ec2_user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    # Let containers reach IMDSv2 for EC2 identity and application AWS credentials.
    http_put_response_hop_limit = 2
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
    aws_iam_role_policy_attachment.ec2_ecr,
    aws_iam_role_policy.ec2_application,
    aws_secretsmanager_secret_version.datadog_api_key,
    aws_vpc_security_group_egress_rule.api_outbound
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
