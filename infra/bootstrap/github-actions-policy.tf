
resource "aws_iam_policy" "github_actions_management" {
  name        = "aws-pratice-github-actions-management"
  description = "Allow Terraform lab to manage GitHub Actions OIDC and deployment role"

  policy = file("${path.module}/github-actions-policy.json")
}

resource "aws_iam_user_policy_attachment" "github_actions_management" {
  user       = aws_iam_user.terraform_lab.name
  policy_arn = aws_iam_policy.github_actions_management.arn
}
