
#!/bin/bash
set -euo pipefail

DOMAIN="aws-lab-ghbamorim.duckdns.org"
APP_DIR="/opt/aws-pratice"
CERT_DIR="$APP_DIR/letsencrypt"
WEBROOT="$APP_DIR/acme-webroot"
NGINX_DIR="$APP_DIR/nginx"
NGINX_CONF="$NGINX_DIR/default.conf"
CERT_FILE="$CERT_DIR/live/$DOMAIN/fullchain.pem"
KEY_FILE="$CERT_DIR/live/$DOMAIN/privkey.pem"

cd "$APP_DIR"

# Wait for Docker and the application to become available.
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed yet."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker is not ready yet."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose is not ready yet."
    exit 1
fi

if [ ! -f docker-compose.yml ] || [ ! -f api.env ]; then
    echo "Application initialization is incomplete."
    exit 1
fi

RUNNING=$(docker compose ps --status running --services)

if ! echo "$RUNNING" | grep -qx api \
   || ! echo "$RUNNING" | grep -qx frontend; then
    echo "Application containers are not running yet."
    exit 1
fi

mkdir -p "$CERT_DIR" "$WEBROOT" "$NGINX_DIR"

# Mount the Nginx configuration and certificate directories.
cat > docker-compose.https.yml <<'YAML'
services:
  frontend:
    volumes:
      - /opt/aws-pratice/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - /opt/aws-pratice/letsencrypt:/etc/letsencrypt:ro
      - /opt/aws-pratice/acme-webroot:/var/www/certbot:ro
YAML

# Include the HTTPS override in all subsequent Compose operations.
cat > .env <<'ENV'
COMPOSE_FILE=docker-compose.yml:docker-compose.https.yml
ENV

# Obtain the initial certificate only when it does not exist.
if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
    cat > "$NGINX_CONF" <<'NGINX'
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

    # Start the frontend with the HTTP challenge configuration.
    docker compose up -d --no-deps --force-recreate frontend

    # Request the certificate through the existing Nginx webroot.
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

# Never activate HTTPS without both certificate files.
if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
    echo "TLS certificate files are missing."
    exit 1
fi

# Configure the final Nginx HTTPS virtual host.
cat > "$NGINX_CONF" <<'NGINX'
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

# Validate the configuration before replacing the running frontend.
docker compose run --rm --no-deps frontend nginx -t

# Recreate the frontend so the HTTPS configuration is activated.
docker compose up -d --no-deps --force-recreate frontend

# Verify that the running Nginx accepts its configuration.
docker compose exec -T frontend nginx -t

# Reload the running Nginx to activate the HTTPS listener.
docker compose exec -T frontend nginx -s reload

# Verify that HTTPS is responding locally.
docker compose exec -T frontend wget \
  --no-check-certificate \
  -q \
  -O /dev/null \
  "https://127.0.0.1/"

# Install the automatic certificate renewal script.
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

echo "HTTPS configured successfully for $DOMAIN"
