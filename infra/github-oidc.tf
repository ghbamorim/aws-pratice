
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "aws-pratice-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:ghbamorim@79848031/aws-pratice@1427495511:ref:refs/tags/*"
          }
        }
      }
    ]
  })

  tags = {
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

resource "aws_iam_role_policy" "github_ecr" {
  name = "aws-pratice-github-ecr-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ECRAuthentication"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PushApplicationImages"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage"
        ]

        Resource = [
          "arn:aws:ecr:us-east-2:242627333067:repository/aws-pratice-api",
          "arn:aws:ecr:us-east-2:242627333067:repository/aws-pratice-frontend"
        ]
      },
      {
        Sid    = "DiscoverDeploymentInstance"
        Effect = "Allow"

        Action = [
          "ec2:DescribeInstances",
          "ssm:DescribeInstanceInformation"
        ]

        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
