FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:stable-alpine

RUN apk add --no-cache certbot \
    && mkdir -p /var/www/certbot /etc/letsencrypt

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY https-entrypoint.sh /usr/local/bin/https-entrypoint.sh
COPY --from=build /app/dist /usr/share/nginx/html

RUN sed -i 's/\r$//' /usr/local/bin/https-entrypoint.sh \
    && chmod +x /usr/local/bin/https-entrypoint.sh

EXPOSE 80 443

CMD ["/usr/local/bin/https-entrypoint.sh"]