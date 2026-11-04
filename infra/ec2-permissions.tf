resource "aws_iam_role_policy" "ec2_application" {
  name = "aws-pratice-ec2-application-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadPostgresCredentials"
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn
      },
      {
        Sid    = "InvokeApplicationLambda"
        Effect = "Allow"

        Action = [
          "lambda:InvokeFunction"
        ]

        Resource = aws_lambda_function.processor.arn
      },
      {
        # Allow the EC2 instance to read the Datadog API key.
        Sid    = "ReadDatadogApiKey"
        Effect = "Allow"

        Action = "secretsmanager:GetSecretValue"

        Resource = aws_secretsmanager_secret.datadog_api_key.arn
      },

    ]
  })
}