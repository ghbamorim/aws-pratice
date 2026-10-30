resource "aws_iam_role" "ec2" {
  name = "aws-pratice-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "ec2_app" {
  name = "aws-pratice-ec2-app-access"

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
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = [
          aws_ecr_repository.api.arn,
          aws_ecr_repository.frontend.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_app.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "aws-pratice-ec2-profile"
  role = aws_iam_role.ec2.name
}
