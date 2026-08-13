#!/bin/sh
# ---------------------------------------------------------------------------- #
# WordPress entrypoint.                                                        #
#  1. Reads passwords from the mounted secrets.                                #
#  2. Waits until MariaDB answers (bounded loop — not a keep-alive hack).      #
#  3. On first boot: downloads WordPress, creates wp-config.php, installs      #
#     WordPress (administrator) and creates the second user.                   #
#  4. exec php-fpm as PID 1.                                                   #
# ---------------------------------------------------------------------------- #
set -e

DB_PASSWORD=$(cat "${MYSQL_PASSWORD_FILE}")
WP_ADMIN_PASSWORD=$(cat "${WP_ADMIN_PASSWORD_FILE}")
WP_USER_PASSWORD=$(cat "${WP_USER_PASSWORD_FILE}")

mkdir -p /var/www/html

echo "[wordpress] Waiting for MariaDB..."
i=0
until mysqladmin ping -h mariadb -u "${MYSQL_USER}" -p"${DB_PASSWORD}" --silent 2>/dev/null; do
    i=$((i + 1))
    if [ "${i}" -ge 60 ]; then
        echo "error: MariaDB did not become ready in time." >&2
        exit 1
    fi
    sleep 2
done
echo "[wordpress] MariaDB is up."

if [ ! -f /var/www/html/wp-config.php ]; then
    echo "[wordpress] Downloading WordPress core..."
    wp core download --path=/var/www/html --allow-root --quiet

    echo "[wordpress] Creating wp-config.php..."
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --path=/var/www/html \
        --allow-root --quiet --skip-check

    echo "[wordpress] Installing WordPress (administrator: ${WP_ADMIN_USER})..."
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --path=/var/www/html \
        --allow-root --quiet --skip-email

    echo "[wordpress] Creating second user (${WP_USER})..."
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --path=/var/www/html \
        --allow-root --quiet

    echo "[wordpress] Installation done."
fi

# php-fpm workers run as nobody: make sure they own the site files.
chown -R nobody:nobody /var/www/html

echo "[wordpress] Starting php-fpm..."
exec php-fpm83 -F
