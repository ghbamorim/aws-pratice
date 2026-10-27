resource "aws_iam_policy" "s3_attachments" {
  name = "aws-pratice-s3-attachments-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageAttachmentsBucket"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:DeleteBucketTagging",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:DeleteBucketPublicAccessBlock",
          "s3:GetBucketVersioning",
          "s3:ListBucketVersions",
          "s3:GetBucketWebsite",
          "s3:GetBucketLogging",
          "s3:GetBucketCORS",
          "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketOwnershipControls"
        ]
        Resource = "arn:aws:s3:::aws-pratice-attachments-*"
      },
      {
        Sid    = "ManageAttachmentsObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = "arn:aws:s3:::aws-pratice-attachments-*/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "s3_attachments" {
  user       = aws_iam_user.terraform_lab.name
  policy_arn = aws_iam_policy.s3_attachments.arn
}