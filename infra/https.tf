resource "aws_ssm_document" "https" {
  name          = "aws_pratice_configure_https"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure HTTPS with Certbot"

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "configureHttps"

        inputs = {
          runCommand = [
            trimspace(replace(<<-SCRIPT
              set -euo pipefail

              DOMAIN="${var.duckdns_domain}"
              EXPECTED_IP="${aws_eip.app.public_ip}"
              DNS_TIMEOUT=300
              DNS_INTERVAL=10
              DEADLINE=$((SECONDS + DNS_TIMEOUT))

              # Wait for DNS propagation
              until [ "$(getent ahostsv4 "$DOMAIN" | awk 'NR==1 {print $1}')" = "$EXPECTED_IP" ]; do
                if [ "$SECONDS" -ge "$DEADLINE" ]; then
                  echo "ERROR: DNS propagation timed out after $DNS_TIMEOUT seconds for $DOMAIN" >&2
                  exit 1
                fi

                sleep "$DNS_INTERVAL"
              done

              # Wait for EC2 initialization
              cloud-init status --wait

              # Verify Nginx configuration
              test -f /etc/nginx/conf.d/app.conf
              nginx -t
              systemctl is-active --quiet nginx

              # Request and install HTTPS certificate
              certbot --nginx \
                --non-interactive \
                --agree-tos \
                --register-unsafely-without-email \
                --redirect \
                -d "$DOMAIN"

              # Enable automatic certificate renewal
              systemctl enable --now certbot-renew.timer
            SCRIPT
            , "\r\n", "\n"))
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "https" {
  name = aws_ssm_document.https.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app.id]
  }

  depends_on = [
    terraform_data.duckdns
  ]
}