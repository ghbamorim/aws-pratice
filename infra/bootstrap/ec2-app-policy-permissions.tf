resource "aws_iam_policy" "ec2_app_policy_management" {
  name = "aws-pratice-ec2-app-policy-management"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ManageEc2AppPolicy"
        Effect = "Allow"

        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListEntitiesForPolicy"
        ]

        Resource = "arn:aws:iam::242627333067:policy/aws-pratice-ec2-app-access"
      },
      {
        Sid    = "AttachEc2AppPolicy"
        Effect = "Allow"

        Action = [
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy"
        ]

        Resource = "arn:aws:iam::242627333067:role/aws-pratice-ec2-role"

        Condition = {
          ArnEquals = {
            "iam:PolicyARN" = "arn:aws:iam::242627333067:policy/aws-pratice-ec2-app-access"
          }
        }
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "ec2_app_policy_management" {
  user       = aws_iam_user.terraform_lab.name
  policy_arn = aws_iam_policy.ec2_app_policy_management.arn
}