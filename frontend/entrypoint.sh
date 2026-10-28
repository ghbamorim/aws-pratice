
#!/bin/sh
set -eu

DOMAIN="aws-lab-ghbamorim.duckdns.org"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
HTTP_CONFIG="/etc/nginx/http.d/default.conf"
HTTPS_CONFIG="/etc/nginx/nginx.https.conf"


mkdir -p /var/www/certbot

# Inicia o Nginx em HTTP para validação ACME.
nginx

# Solicita o certificado apenas se ainda não existir.
if [ ! -s "$CERT_DIR/fullchain.pem" ] || [ ! -s "$CERT_DIR/privkey.pem" ]; then
    echo "Solicitando certificado para $DOMAIN..."

    until certbot certonly \
        --webroot \
        --webroot-path /var/www/certbot \
        --domain "$DOMAIN" \
        --register-unsafely-without-email \
        --agree-tos \
        --non-interactive; do

        echo "Falha na emissão do certificado. Nova tentativa em 60 segundos."
        sleep 60
    done
fi

# Ativa a configuração HTTPS.
cp "$HTTPS_CONFIG" "$HTTP_CONFIG"
nginx -t
nginx -s reload

echo "HTTPS ativado para $DOMAIN"

# Renova certificados periodicamente.
(
    while true; do
        sleep 12h

        if certbot renew --non-interactive; then
            nginx -t && nginx -s reload
        else
            echo "Falha na renovação do certificado."
        fi
    done
) &

# Mantém o contêiner ativo e supervisiona o Nginx.
while kill -0 "$(cat /run/nginx/nginx.pid)" 2>/dev/null; do
    sleep 5
done

echo "Nginx encerrou inesperadamente."
exit 1
