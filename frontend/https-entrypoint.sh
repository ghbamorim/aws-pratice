#!/bin/sh
set -eu

DOMAIN="aws-lab-ghbamorim.duckdns.org"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
WEBROOT="/var/www/certbot"

mkdir -p "$WEBROOT"

# Inicia Nginx em HTTP para validar o domínio.
nginx

# Emite o certificado caso ainda não exista.
if [ ! -s "$CERT_DIR/fullchain.pem" ] || [ ! -s "$CERT_DIR/privkey.pem" ]; then
    certbot certonly \
        --webroot \
        --webroot-path "$WEBROOT" \
        --domain "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email
fi

# Configura HTTP -> HTTPS e o proxy da API.
cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root $WEBROOT;
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate $CERT_DIR/fullchain.pem;
    ssl_certificate_key $CERT_DIR/privkey.pem;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://api:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /health {
        proxy_pass http://api:8000/health;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

nginx -t
nginx -s reload

# Renovação automática, com recarga após renovação bem-sucedida.
(
    while true; do
        sleep 12h
        certbot renew --quiet --deploy-hook "nginx -s reload" || true
    done
) &

# Monitora o processo principal do Nginx.
while kill -0 "$(cat /run/nginx.pid)" 2>/dev/null; do
    sleep 5
done

echo "Nginx encerrou inesperadamente." >&2
exit 1