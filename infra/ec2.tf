data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    dnf update -y
    dnf install -y docker

    systemctl enable --now docker

    mkdir -p /usr/local/lib/docker/cli-plugins

    curl -fSL \
      https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose

    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    mkdir -p /opt/aws-pratice
    chmod 700 /opt/aws-pratice
  EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "aws-pratice-app"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy_attachment.app
  ]
}

output "ec2_instance_id" {
  value = aws_instance.app.id
}

output "ec2_public_ip" {
  value = aws_instance.app.public_ip
}
