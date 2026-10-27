
resource "aws_instance" "app" {
  ami                         = "ami-01cb65bdf4b589c2d"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/ec2-user-data.sh.tftpl", {
    docker_compose = base64encode(templatefile("${path.module}/docker-compose.yml", {
      api_image      = "${aws_ecr_repository.api.repository_url}:latest"
      frontend_image = "${aws_ecr_repository.frontend.repository_url}:latest"
      aws_region     = "us-east-2"
      s3_bucket      = aws_s3_bucket.attachments.id
      db_secret_arn  = aws_db_instance.postgres.master_user_secret[0].secret_arn
      db_host        = aws_db_instance.postgres.address
      db_port        = aws_db_instance.postgres.port
      db_name        = aws_db_instance.postgres.db_name
    }))

    aws_region    = "us-east-2"
    ecr_registry  = "242627333067.dkr.ecr.us-east-2.amazonaws.com"
    db_secret_arn = aws_db_instance.postgres.master_user_secret[0].secret_arn
    db_host       = aws_db_instance.postgres.address
    db_port       = aws_db_instance.postgres.port
    db_name       = aws_db_instance.postgres.db_name
  })

  tags = {
    Name = "aws-pratice-app"
  }
}

resource "aws_eip" "app" {
  domain = "vpc"

  tags = {
    Name = "aws-pratice-app-eip"
  }
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}

output "ec2_instance_id" {
  description = "Application EC2 instance ID"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Application Elastic IP address"
  value       = aws_eip.app.public_ip
}
