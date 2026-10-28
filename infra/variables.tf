variable "duckdns_token" {
  description = "Token da API DuckDNS"
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(trimspace(var.duckdns_token)) > 0
    error_message = "O token DuckDNS é obrigatório."
  }
}