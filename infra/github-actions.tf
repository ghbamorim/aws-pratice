data "aws_caller_identity" "github_actions" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "aws-pratice-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:ghbamorim/aws-pratice:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "aws-pratice-github-actions-deploy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = [
          aws_ecr_repository.api.arn,
          aws_ecr_repository.frontend.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          "arn:aws:ssm:us-east-2::document/AWS-RunShellScript",
          aws_instance.app.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions using OIDC"
  value       = aws_iam_role.github_actions_deploy.arn
}