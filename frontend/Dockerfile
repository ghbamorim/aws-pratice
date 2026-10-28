
FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM alpine:3.21

RUN apk add --no-cache nginx certbot openssl

RUN mkdir -p \
    /run/nginx \
    /var/www/certbot \
    /etc/letsencrypt \
    /usr/share/nginx/html

COPY --from=build /app/dist/ /usr/share/nginx/html/

COPY nginx.conf /etc/nginx/http.d/default.conf
COPY nginx.https.conf /etc/nginx/nginx.https.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
