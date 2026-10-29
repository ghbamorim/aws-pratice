data "aws_caller_identity" "application" {}

resource "aws_s3_bucket" "attachments" {
  bucket = "aws-pratice-attachments-${data.aws_caller_identity.application.account_id}"

  force_destroy = true

  tags = {
    Name = "aws-pratice-attachments"
  }
}

resource "aws_s3_bucket_public_access_block" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  versioning_configuration {
    status = "Suspended"
  }
}
