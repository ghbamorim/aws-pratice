resource "aws_secretsmanager_secret" "duckdns" {
  name                    = "aws-pratice-duckdns-token"
  recovery_window_in_days = 0

  tags = {
    Name = "aws-pratice-duckdns-token"
  }
}

resource "aws_secretsmanager_secret_version" "duckdns" {
  secret_id                = aws_secretsmanager_secret.duckdns.id
  secret_string_wo         = var.duckdns_token
  secret_string_wo_version = 1
}