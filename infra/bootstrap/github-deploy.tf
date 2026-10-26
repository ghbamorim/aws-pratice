data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid    = "SendDeployCommand"
    effect = "Allow"

    actions = [
      "ssm:SendCommand"
    ]

    resources = [
      "arn:aws:ssm:us-east-2::document/AWS-RunShellScript",
      "arn:aws:ec2:us-east-2:242627333067:instance/i-078cd92714f6cb663"
    ]
  }

  statement {
    sid    = "CheckDeployResult"
    effect = "Allow"

    actions = [
      "ssm:GetCommandInvocation"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "aws-pratice-github-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
