resource "aws_iam_role_policy" "github_ssm" {
  name = "aws-pratice-github-ssm-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ssm:SendCommand"
        ]


        Resource = [
          aws_ssm_document.deploy.arn,
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