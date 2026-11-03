
resource "aws_iam_user" "terraform_admin" {
  name = "terraform-admin"
  path = "/"
}

resource "aws_iam_group" "terraform_administrators" {
  name = "TerraformAdministrators"
  path = "/"
}

resource "aws_iam_user_group_membership" "terraform_admin" {
  user = aws_iam_user.terraform_admin.name

  groups = [
    aws_iam_group.terraform_administrators.name
  ]
}

resource "aws_iam_group_policy_attachment" "administrator_access" {
  group      = aws_iam_group.terraform_administrators.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
