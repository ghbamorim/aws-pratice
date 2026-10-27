resource "aws_s3_bucket" "attachments" {
  bucket_prefix = "aws-pratice-attachments-"

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

output "s3_attachments_bucket" {
  description = "S3 bucket for application attachments"
  value       = aws_s3_bucket.attachments.id
}