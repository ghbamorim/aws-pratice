resource "aws_iam_policy" "terraform_lab" {
  name        = "TerraformLabInfrastructurePolicy"
  description = "Permissions for managing the AWS practice infrastructure"

  policy = file("${path.module}/terraform-lab-policy.json")
}

resource "aws_iam_user_policy_attachment" "terraform_lab" {
  user       = "terraform-lab"
  policy_arn = aws_iam_policy.terraform_lab.arn
}
