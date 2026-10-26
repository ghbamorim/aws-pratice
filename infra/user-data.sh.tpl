#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y docker nginx certbot python3-certbot-nginx

systemctl enable --now docker nginx
usermod -aG docker ec2-user

cat > /etc/nginx/conf.d/app.conf <<'NGINX'
server {
    listen 80;
    server_name ${domain};

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
NGINX

nginx -t
systemctl reload nginx