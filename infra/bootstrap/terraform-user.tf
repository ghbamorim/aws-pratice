resource "aws_iam_user" "terraform_lab" {
  name = "terraform-lab"
}

# Preserve os endereços Terraform existentes (terraform_lab_service).
locals {
  lab_policies = {
    ec2     = "terraform-lab-ec2-policy.json"
    ecr     = "terraform-lab-ecr-policy.json"
    iam     = "terraform-lab-iam-policy.json"
    rds     = "terraform-lab-rds-policy.json"
    ssm     = "terraform-lab-ssm-policy.json"
    secrets = "terraform-lab-secrets-policy.json"
  }
}

resource "aws_iam_policy" "terraform_lab_service" {
  for_each = local.lab_policies

  name   = "aws-pratice-terraform-lab-${each.key}-policy"
  policy = file("${path.module}/${each.value}")
}

resource "aws_iam_user_policy_attachment" "terraform_lab_service" {
  for_each = aws_iam_policy.terraform_lab_service

  user       = aws_iam_user.terraform_lab.name
  policy_arn = each.value.arn
}
