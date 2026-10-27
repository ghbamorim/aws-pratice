
#!/bin/bash
set -euo pipefail

DOMAIN="aws-lab-ghbamorim.duckdns.org"
APP_DIR="/opt/aws-pratice"
CERT_DIR="$APP_DIR/letsencrypt"
WEBROOT="$APP_DIR/acme-webroot"
NGINX_DIR="$APP_DIR/nginx"
CERT_FILE="$CERT_DIR/live/$DOMAIN/fullchain.pem"

# Wait for EC2 initialization.
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed yet."
    exit 0
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker is not ready yet."
    exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose is not ready yet."
    exit 0
fi

if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
    echo "Application Compose file is not ready yet."
    exit 0
fi

if [ ! -f "$APP_DIR/api.env" ]; then
    echo "Application environment is not ready yet."
    exit 0
fi

cd "$APP_DIR"

# Wait for the GitHub release to deploy both containers.
RUNNING=$(docker compose ps --status running --services)

if ! echo "$RUNNING" | grep -qx api \
   || ! echo "$RUNNING" | grep -qx frontend; then
    echo "Application release is not running yet."
    exit 0
fi

mkdir -p "$CERT_DIR" "$WEBROOT" "$NGINX_DIR"

# Add HTTPS mounts without changing release image tags.
cat > docker-compose.https.yml <<'YAML'
services:
  frontend:
    volumes:
      - /opt/aws-pratice/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - /opt/aws-pratice/letsencrypt:/etc/letsencrypt:ro
      - /opt/aws-pratice/acme-webroot:/var/www/certbot:ro
YAML

# Apply the HTTPS override to subsequent Compose commands.
cat > .env <<'ENV'
COMPOSE_FILE=docker-compose.yml:docker-compose.https.yml
ENV

# Use HTTP for the initial certificate challenge only.
if [ ! -s "$CERT_FILE" ]; then
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

    docker compose up -d --no-deps --force-recreate frontend

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

# Configure HTTPS and preserve the ACME challenge endpoint.
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

# Validate and activate the Nginx HTTPS configuration.
docker compose run --rm --no-deps frontend nginx -t
docker compose up -d --no-deps frontend
docker compose exec -T frontend nginx -s reload

# Install automatic certificate renewal.
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
