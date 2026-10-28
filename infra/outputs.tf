output "cloudfront_url" {
  description = "URL HTTPS do frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "ID da distribuicao CloudFront"
  value       = aws_cloudfront_distribution.frontend.id
}