resource "aws_ecr_repository" "api" {
  name                 = "aws-pratice-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "aws-pratice-api"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "aws-pratice-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "aws-pratice-frontend"
  }
}