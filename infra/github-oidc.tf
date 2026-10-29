
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name = "aws-pratice-github-oidc"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "AllowGitHubReleaseTags"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

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
        "repo:ghbamorim@79848031/aws-pratice@1427495511:ref:refs/tags/v*.*.*"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "aws-pratice-github-actions-deploy"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "aws-pratice-github-actions-deploy"
  }
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions_deploy.arn
}
