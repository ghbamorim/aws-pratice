
#!/bin/bash
set -euo pipefail

DOMAIN="aws-lab-ghbamorim.duckdns.org"
APP_DIR="/opt/aws-pratice"
CERT_DIR="$APP_DIR/letsencrypt"
WEBROOT="$APP_DIR/acme-webroot"
NGINX_DIR="$APP_DIR/nginx"

mkdir -p "$CERT_DIR" "$WEBROOT" "$NGINX_DIR"
cd "$APP_DIR"

# Preserve the existing Compose application and release image tags.
cat > docker-compose.https.yml <<'YAML'
services:
  frontend:
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/aws-pratice/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - /opt/aws-pratice/letsencrypt:/etc/letsencrypt:ro
      - /opt/aws-pratice/acme-webroot:/var/www/certbot:ro
YAML

# Make every Docker Compose invocation use the HTTPS override.
cat > .env <<'ENV'
COMPOSE_FILE=docker-compose.yml:docker-compose.https.yml
ENV

# Bootstrap HTTP configuration for certificate issuance.
cat > "$NGINX_DIR/default.conf" <<'NGINX'
server {
    listen 80;
    server_name aws-lab-ghbamorim.duckdns.org;

    root /usr/share/nginx/html;
    index index.html;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type text/plain;
    }

    location /api/ {
        proxy_pass http://api:8000;
    }

    location /health {
        proxy_pass http://api:8000/health;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# Recreate the frontend with the mounted HTTP configuration.
docker compose up -d --no-deps --force-recreate frontend

# Obtain the first certificate without interactive prompts.
if [ ! -f "$CERT_DIR/live/$DOMAIN/fullchain.pem" ]; then
    docker run --rm \
      -v "$CERT_DIR:/etc/letsencrypt" \
      -v "$WEBROOT:/var/www/certbot" \
      certbot/certbot:latest certonly \
      --webroot \
      -w /var/www/certbot \
      -d "$DOMAIN" \
      --agree-tos \
      --register-unsafely-without-email \
      --non-interactive
fi

# Activate HTTPS and redirect HTTP traffic.
cat > "$NGINX_DIR/default.conf" <<'NGINX'
server {
    listen 80;
    server_name aws-lab-ghbamorim.duckdns.org;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type text/plain;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name aws-lab-ghbamorim.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/aws-lab-ghbamorim.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/aws-lab-ghbamorim.duckdns.org/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://api:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://api:8000/health;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

# Validate the HTTPS configuration before activating it.
docker compose run --rm --no-deps frontend nginx -t
docker compose up -d --no-deps --force-recreate frontend

# Create a renewal script.
cat > /usr/local/bin/aws-pratice-renew-cert <<'SCRIPT'
#!/bin/bash
set -euo pipefail

docker run --rm \
  -v /opt/aws-pratice/letsencrypt:/etc/letsencrypt \
  -v /opt/aws-pratice/acme-webroot:/var/www/certbot \
  certbot/certbot:latest renew \
  --webroot \
  -w /var/www/certbot \
  --quiet

cd /opt/aws-pratice
docker compose exec -T frontend nginx -s reload
SCRIPT

chmod +x /usr/local/bin/aws-pratice-renew-cert

cat > /etc/systemd/system/aws-pratice-cert-renew.service <<'SERVICE'
[Unit]
Description=Renew AWS Pratice TLS certificates
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/aws-pratice-renew-cert
SERVICE

cat > /etc/systemd/system/aws-pratice-cert-renew.timer <<'TIMER'
[Unit]
Description=Check AWS Pratice TLS certificates daily

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now aws-pratice-cert-renew.timer

echo "HTTPS configured for $DOMAIN"
