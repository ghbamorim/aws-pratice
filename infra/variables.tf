variable "db_password" {
  description = "Password for the PostgreSQL application user"
  type        = string
  sensitive   = true
}

variable "duckdns_domain" {
  description = "DuckDNS hostname used for HTTPS"
  type        = string
}