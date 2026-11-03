locals {
  policy_names = toset([
    "backend",
    "ec2",
    "ecr",
    "iam",
    "rds",
    "secrets",
    "ssm",
    "cloudwatch",
    "lambda"
  ])
}

resource "aws_iam_user" "terraform_lab" {
  name = "terraform-lab"
  path = "/"
}

resource "aws_iam_policy" "terraform_lab_service" {
  for_each = local.policy_names

  name   = "aws-pratice-terraform-lab-${each.key}-policy"
  policy = file("${path.module}/policies/${each.key}.json")
}

resource "aws_iam_user_policy_attachment" "terraform_lab_service" {
  for_each = local.policy_names

  user       = aws_iam_user.terraform_lab.name
  policy_arn = aws_iam_policy.terraform_lab_service[each.key].arn
}
