#!/bin/sh
# ---------------------------------------------------------------------------- #
# NGINX entrypoint.                                                            #
#  1. Generates a self-signed TLS certificate for the domain (once).           #
#  2. Renders the configuration template (envsubst for ${DOMAIN_NAME}).        #
#  3. exec "$@" → "nginx -g daemon off;" as PID 1 (foreground, no hacks).      #
# ---------------------------------------------------------------------------- #
set -e

if [ ! -f /etc/nginx/ssl/nginx.crt ] || [ ! -f /etc/nginx/ssl/nginx.key ]; then
    echo "[nginx] Generating self-signed TLS certificate for ${DOMAIN_NAME}..."
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/nginx.key \
        -out /etc/nginx/ssl/nginx.crt \
        -subj "/C=MA/ST=Khouribga/L=Khouribga/O=1337/OU=42/CN=${DOMAIN_NAME}" \
        -addext "subjectAltName=DNS:${DOMAIN_NAME}" \
        >/dev/null 2>&1
fi

echo "[nginx] Rendering configuration..."
envsubst '${DOMAIN_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

mkdir -p /var/lib/nginx/tmp
chown -R nginx:nginx /var/lib/nginx/tmp /var/lib/nginx

exec "$@"
