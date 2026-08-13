#!/bin/sh
# ---------------------------------------------------------------------------- #
# MariaDB entrypoint.                                                          #
#  1. Reads the passwords from the mounted secrets (/run/secrets/...).         #
#  2. Initializes the data directory on first boot: creates the database       #
#     and the two accounts (root + application user).                          #
#  3. exec mariadbd as PID 1 — no "tail -f", no "sleep infinity", no daemon    #
#     started in the background.                                               #
# ---------------------------------------------------------------------------- #
set -e

MYSQL_ROOT_PASSWORD=""
MYSQL_PASSWORD=""

if [ -f "${MYSQL_ROOT_PASSWORD_FILE}" ]; then
    MYSQL_ROOT_PASSWORD=$(cat "${MYSQL_ROOT_PASSWORD_FILE}")
fi
if [ -f "${MYSQL_PASSWORD_FILE}" ]; then
    MYSQL_PASSWORD=$(cat "${MYSQL_PASSWORD_FILE}")
fi

if [ -z "${MYSQL_ROOT_PASSWORD}" ] || [ -z "${MYSQL_PASSWORD}" ]; then
    echo "error: database passwords are missing (check the secrets files)." >&2
    exit 1
fi

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# First boot only: the data directory is empty (or missing its system tables).
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[mariadb] Initializing data directory..."

    mariadb-install-db --user=mysql --datadir=/var/lib/mysql \
        --auth-root-authentication-method=normal

    echo "[mariadb] Creating database and users..."

    # --bootstrap: the server reads SQL from stdin without opening any socket,
    # then exits. This is the official way to run maintenance SQL.
    mariadbd --user=mysql --datadir=/var/lib/mysql --bootstrap <<EOF
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    echo "[mariadb] Initialization done."
fi

echo "[mariadb] Starting server..."
exec mariadbd --user=mysql --datadir=/var/lib/mysql
