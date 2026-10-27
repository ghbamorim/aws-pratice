resource "aws_ecr_repository" "api" {
  name                 = "aws-pratice-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "aws-pratice-api"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "aws-pratice-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "aws-pratice-frontend"
  }
}

output "ecr_api_url" {
  description = "Backend Docker image repository URL"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_frontend_url" {
  description = "Frontend Docker image repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}