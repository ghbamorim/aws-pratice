resource "aws_ecr_repository" "frontend" {
  name                 = "aws-pratice-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "aws-pratice-frontend"
  }
}

resource "aws_ecr_repository" "api" {
  name                 = "aws-pratice-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "aws-pratice-api"
  }
}
