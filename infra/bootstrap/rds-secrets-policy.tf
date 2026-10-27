resource "aws_iam_policy" "rds_secrets" {
  name = "aws-pratice-rds-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageRdsMasterSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DeleteSecret",
          "secretsmanager:RestoreSecret"
        ]
        Resource = "arn:aws:secretsmanager:us-east-2:242627333067:secret:rds!*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "rds_secrets" {
  user       = aws_iam_user.terraform_lab.name
  policy_arn = aws_iam_policy.rds_secrets.arn
}