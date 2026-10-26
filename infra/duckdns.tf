variable "duckdns_token" {
  type      = string
  sensitive = true
}

resource "terraform_data" "duckdns" {
  triggers_replace = {
    public_ip = aws_eip.app.public_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
    response=$(curl --fail --silent --show-error --get \
      --data-urlencode "domains=${split(".", var.duckdns_domain)[0]}" \
      --data-urlencode "token=$DUCKDNS_TOKEN" \
      --data-urlencode "ip=${aws_eip.app.public_ip}" \
      https://www.duckdns.org/update)

    test "$response" = "OK"
  EOT

    interpreter = ["bash", "-c"]

    environment = {
      DUCKDNS_TOKEN = var.duckdns_token
    }
  }

  depends_on = [aws_eip_association.app]
}