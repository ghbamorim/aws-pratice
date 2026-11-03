resource "aws_iam_role_policy" "github_deploy_ssm" {
  name = "aws-pratice-github-deploy-ssm"
  role = "aws-pratice-github-actions-deploy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "SendDeployCommand"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          "arn:aws:ssm:us-east-2::document/AWS-RunShellScript",
          aws_instance.api.arn
        ]
      },
      {
        Sid    = "ReadDeployCommandResult"
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      }
    ]
  })
}
