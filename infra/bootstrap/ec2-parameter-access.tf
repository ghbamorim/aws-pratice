resource "aws_iam_role_policy" "ec2_database_password" {
  name = "aws-pratice-read-db-password"
  role = "aws-pratice-ec2-role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:us-east-2:242627333067:parameter/pratice/database/password"
      }
    ]
  })
}
