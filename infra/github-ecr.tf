data "aws_iam_policy_document" "github_ecr" {
  statement {
    sid    = "EcrAuthorization"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PushDockerImages"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = [
      aws_ecr_repository.frontend.arn,
      aws_ecr_repository.api.arn
    ]
  }
}

resource "aws_iam_role_policy" "github_ecr" {
  name = "aws-pratice-github-ecr"
  role = aws_iam_role.github_actions_deploy.id

  policy = data.aws_iam_policy_document.github_ecr.json
}
