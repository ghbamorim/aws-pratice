resource "aws_iam_user" "terraform_lab" {
  name = "terraform-lab"
}

resource "aws_iam_policy" "terraform_lab" {
  name   = "aws-pratice-terraform-lab-policy"
  policy = file("${path.module}/terraform-lab-policy.json")
}

resource "aws_iam_user_policy_attachment" "terraform_lab" {
  user       = aws_iam_user.terraform_lab.name
  policy_arn = aws_iam_policy.terraform_lab.arn
}