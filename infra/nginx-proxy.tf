resource "aws_ssm_document" "nginx_proxy" {
  name          = "aws_pratice_configure_nginx_proxy"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Configure Nginx reverse proxy for Docker frontend"

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "configureProxy"

        inputs = {
          runCommand = [
            trimspace(<<-SCRIPT
              set -euo pipefail

              cloud-init status --wait

              CONFIG=/etc/nginx/conf.d/app.conf
              test -f "$CONFIG"

              python3 - <<'PY'
              from pathlib import Path

              path = Path("/etc/nginx/conf.d/app.conf")
              content = path.read_text()

              old = """location / {
                      root /usr/share/nginx/html;
                      index index.html;
                  }"""

              new = """location / {
                      proxy_pass http://127.0.0.1:8080;
                      proxy_http_version 1.1;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                  }"""

              if old in content:
                  path.write_text(content.replace(old, new, 1))
              elif new not in content:
                  raise SystemExit("Unexpected Nginx configuration")
              PY

              nginx -t
              systemctl reload nginx
            SCRIPT
            )
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "nginx_proxy" {
  name = aws_ssm_document.nginx_proxy.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app.id]
  }

  depends_on = [
    aws_ssm_association.https
  ]
}
