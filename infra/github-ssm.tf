
data "aws_iam_policy_document" "github_ssm" {
  statement {
    sid    = "SendDeploymentCommand"
    effect = "Allow"

    actions = [
      "ssm:SendCommand"
    ]

    resources = [
      "arn:aws:ssm:us-east-2::document/AWS-RunShellScript",
      aws_instance.app.arn
    ]
  }

  statement {
    sid    = "ReadDeploymentCommandStatus"
    effect = "Allow"

    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DescribeDeploymentResources"
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "rds:DescribeDBInstances"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_ssm" {
  name   = "aws-pratice-github-ssm"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_ssm.json
}
