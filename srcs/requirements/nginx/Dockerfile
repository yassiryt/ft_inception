# **************************************************************************** #
# NGINX — based on the penultimate stable version of Alpine (3.23).            #
# The ONLY entry point of the infrastructure: port 443 only, TLSv1.2/1.3.      #
# **************************************************************************** #
FROM alpine:3.23

RUN apk update && apk add --no-cache \
        nginx \
        openssl \
        gettext

# Template rendered at container start (envsubst replaces ${DOMAIN_NAME}).
COPY conf/nginx.conf.template /etc/nginx/nginx.conf.template

COPY tools/script.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

# Entrypoint: generate the self-signed TLS certificate, render the config,
# then exec nginx in the foreground as PID 1 (daemon off; is the canonical
# way to run nginx in a container, not a hacky patch).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
