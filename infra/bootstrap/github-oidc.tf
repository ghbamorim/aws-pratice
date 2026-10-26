resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:ghbamorim@79848031/aws-pratice@1427495511:ref:refs/heads/main",
        "repo:ghbamorim@79848031/aws-pratice@1427495511:ref:refs/tags/v*"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "aws-pratice-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

data "aws_iam_policy_document" "github_ecr" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:DescribeImages",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      "arn:aws:ecr:us-east-2:242627333067:repository/aws-pratice-api",
      "arn:aws:ecr:us-east-2:242627333067:repository/aws-pratice-frontend"
    ]
  }
}

resource "aws_iam_role_policy" "github_ecr" {
  name   = "aws-pratice-github-ecr"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_ecr.json
}
