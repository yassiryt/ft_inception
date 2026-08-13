# **************************************************************************** #
# WordPress + php-fpm — based on the penultimate stable version of Alpine      #
# (3.23). Nginx is NOT part of this image (subject requirement).               #
# **************************************************************************** #
FROM alpine:3.23

RUN apk update && apk add --no-cache \
        php83 \
        php83-fpm \
        php83-mysqli \
        php83-curl \
        php83-gd \
        php83-mbstring \
        php83-exif \
        php83-fileinfo \
        php83-openssl \
        php83-xml \
        php83-dom \
        php83-simplexml \
        php83-xmlreader \
        php83-xmlwriter \
        php83-zip \
        php83-phar \
        php83-iconv \
        php83-ctype \
        php83-tokenizer \
        php83-session \
        mariadb-client \
        curl

# Alpine installs versioned binaries only: give wp-cli the plain "php" name.
RUN ln -s /usr/bin/php83 /usr/bin/php

# WP-CLI: the official WordPress command line tool (used at container start to
# download/configure/install WordPress, not to run it).
RUN curl -fsSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# php-fpm pool configuration (listen on 0.0.0.0:9000 for the nginx container).
COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

COPY tools/script.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000

# Entrypoint: wait for the database, install WordPress on first boot, then
# exec php-fpm as PID 1.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm83", "-F"]
