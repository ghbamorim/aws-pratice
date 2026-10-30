resource "aws_eip" "app" {
  domain = "vpc"

  tags = {
    Name = "aws-pratice-app"
  }
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}