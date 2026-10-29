data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y docker

    systemctl enable --now docker

    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fL --retry 3 \
      "https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-x86_64" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose

    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    mkdir -p /opt/aws-pratice

    cat > /opt/aws-pratice/compose.yaml <<'COMPOSE'
    services: {}
    COMPOSE

    systemctl enable --now amazon-ssm-agent
  EOF

  user_data_replace_on_change = false

  tags = {
    Name = "aws-pratice-app"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ec2_app_access,
    aws_iam_role_policy_attachment.ec2_ssm
  ]
}
