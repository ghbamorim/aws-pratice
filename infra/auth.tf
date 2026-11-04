resource "aws_cloudfront_key_value_store" "auth" {
  name    = "aws-pratice-auth"
  comment = "Credentials for the practice lab"
}

resource "aws_cloudfront_function" "auth" {
  name    = "aws-pratice-auth"
  runtime = "cloudfront-js-2.0"
  comment = "Basic authentication for the practice lab"
  publish = true
  code    = file("${path.module}/auth.js")

  key_value_store_associations = [
    aws_cloudfront_key_value_store.auth.arn
  ]
}

output "auth_kvs_arn" {
  value = aws_cloudfront_key_value_store.auth.arn
}
