
resource "aws_cloudfront_distribution" "app" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "aws-pratice application"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name = aws_instance.app.public_dns
    origin_id   = "aws-pratice-ec2"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"

      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "aws-pratice-ec2"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "aws-pratice-ec2"
    viewer_protocol_policy = "https-only"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "PUT",
      "POST",
      "PATCH",
      "DELETE"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = {
    Name = "aws-pratice-cloudfront"
  }
}

output "cloudfront_url" {
  description = "Public HTTPS URL of the application"
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
}
