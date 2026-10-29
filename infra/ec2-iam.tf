data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "aws-pratice-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "aws-pratice-ec2-profile"
  role = aws_iam_role.ec2.name
}

data "aws_iam_policy_document" "ec2_app_access" {
  statement {
    sid = "EcrAuthorization"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid = "EcrPull"

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability"
    ]

    resources = [
      aws_ecr_repository.api.arn,
      aws_ecr_repository.frontend.arn
    ]
  }

  statement {
    sid = "S3BucketAccess"

    actions = [
      "s3:ListBucket"
    ]

    resources = [aws_s3_bucket.attachments.arn]
  }

  statement {
    sid = "S3ObjectAccess"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = ["${aws_s3_bucket.attachments.arn}/*"]
  }

  statement {
    sid = "ReadDatabaseSecret"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_db_instance.postgres.master_user_secret[0].secret_arn
    ]
  }
}

resource "aws_iam_policy" "ec2_app_access" {
  name   = "aws-pratice-ec2-app-access"
  policy = data.aws_iam_policy_document.ec2_app_access.json
}

resource "aws_iam_role_policy_attachment" "ec2_app_access" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_app_access.arn
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
