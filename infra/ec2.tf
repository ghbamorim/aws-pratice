data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id = "subnet-049b61005ad47f723"

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = replace(templatefile("${path.module}/user-data.sh.tpl", {
    domain = var.duckdns_domain
  }), "\r\n", "\n")

  user_data_replace_on_change = true

  tags = {
    Name = "aws-pratice-app"
  }
}