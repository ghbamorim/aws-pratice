
variable "duckdns_token" {
  description = "DuckDNS API token"
  type        = string
  sensitive   = true
  ephemeral   = true
}

resource "terraform_data" "duckdns_update" {
  triggers_replace = [
    aws_eip.app.public_ip
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu

      RESPONSE=$(curl --fail --silent --show-error \
        --get \
        --data-urlencode "domains=aws-lab-ghbamorim" \
        --data-urlencode "token=$DUCKDNS_TOKEN" \
        --data-urlencode "ip=$DUCKDNS_IP" \
        "https://www.duckdns.org/update")

      if [ "$RESPONSE" != "OK" ]; then
        echo "DuckDNS update failed: $RESPONSE" >&2
        exit 1
      fi

      echo "DuckDNS updated successfully."
    EOT

    interpreter = ["bash", "-c"]

    environment = {
      DUCKDNS_TOKEN = var.duckdns_token
      DUCKDNS_IP    = aws_eip.app.public_ip
    }
  }

  depends_on = [
    aws_eip_association.app
  ]
}
