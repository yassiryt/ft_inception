# **************************************************************************** #
# MariaDB — based on the penultimate stable version of Alpine (3.23)           #
# **************************************************************************** #
FROM alpine:3.23

RUN apk update && apk add --no-cache \
        mariadb \
        mariadb-client

# zz-docker.cnf is read LAST (after the distribution's mariadb-server.cnf,
# which sets "skip-networking") and re-enables TCP + 0.0.0.0 binding.
COPY conf/zz-docker.cnf /etc/my.cnf.d/zz-docker.cnf

COPY tools/script.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3306

# The entrypoint initializes the data directory on first boot (database +
# users), then hands PID 1 over to mariadbd via exec (no daemon hacks).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mariadbd"]
