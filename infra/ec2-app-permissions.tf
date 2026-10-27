resource "aws_iam_policy" "ec2_app_access" {
  name = "aws-pratice-ec2-app-access"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadDatabaseCredentials"
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]

        Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn
      },
      {
        Sid    = "ListAttachmentsBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]

        Resource = aws_s3_bucket.attachments.arn
      },
      {
        Sid    = "ManageAttachments"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = "${aws_s3_bucket.attachments.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_app_access" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_app_access.arn
}