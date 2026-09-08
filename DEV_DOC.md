# DEV_DOC — Inception developer documentation

This document describes how a developer can set up, build, run and debug the
project from scratch, and how the internals are wired together.

## 1. Architecture overview

```
srcs/
├── .env                       non-secret configuration
├── docker-compose.yml         services, network, volumes, secrets
└── requirements/
    ├── mariadb/               Dockerfile, conf/zz-docker.cnf, tools/script.sh
    ├── wordpress/             Dockerfile, conf/www.conf,      tools/script.sh
    └── nginx/                 Dockerfile, conf/nginx.conf.template, tools/script.sh
secrets/                       *.txt password files (mounted as Docker secrets)
Makefile                       orchestrates docker compose
```

Data flow: browser → `nginx:443` (TLS) → fastcgi `wordpress:9000` → mysqli
`mariadb:3306`.

Key rules implemented (subject v5.3):

- one image per service, built from `alpine:3.23` (penultimate stable);
- only nginx exposes a port on the host: `443`;
- dedicated bridge network `inception` (`network: host`, `--link`, `links:`
  are forbidden);
- two named volumes whose data lives in `/home/yatanagh/data`;
- `restart: always` on every service;
- services run as PID 1 via `exec` (`mariadbd`, `php-fpm83 -F`,
  `nginx -g "daemon off;"`) — no `tail -f` / `sleep infinity` / `while true`;
- no password in any Dockerfile; passwords come from Docker secrets; other
  settings from `.env`.

## 2. Prerequisites

On the machine (school VM or your own):

- GNU/Linux (the project is developed and evaluated on 42's Ubuntu VMs);
- **Docker Engine** and the **docker compose v2 plugin**
  (`docker compose version` must work — see SETUP_GUIDE.md to install);
- **make** and **git**;
- your user must be able to run `docker` (docker group), or prefix every
  command with `sudo`.

One-time system configuration:

1. Edit `/etc/hosts` so the domain points to your local IP:

   ```
   127.0.0.1   yatanagh.42.fr
   ```

2. Fill the four files in `secrets/` (one password per file, see
   `secrets/README.md`).

3. In `srcs/.env` and the `Makefile`, replace the placeholder `login` with
   your intra username (`DOMAIN_NAME=you.42.fr`, `DATA_DIR=/home/you/data`,
   `device: /home/you/data/...` in docker-compose.yml).

## 3. Building and launching

```sh
make            # = docker compose -f srcs/docker-compose.yml up -d --build
```

What happens on the very first `make`:

1. `mkdir -p /home/yatanagh/data/{mariadb,wordpress}` (host directories used by
   the volumes).
2. Compose builds the three images from `srcs/requirements/*/Dockerfile`.
3. Containers start; each entrypoint performs its first-boot job:
   - **mariadb**: initializes `/var/lib/mysql` (`mariadb-install-db`), creates
     database `wordpress_db` + users (`mariadbd --bootstrap`), then `exec
     mariadbd`.
   - **wordpress**: waits for the DB (`mysqladmin ping`), downloads WordPress
     core, writes `wp-config.php`, installs the site and creates the 2nd user
     via WP-CLI, then `exec php-fpm83 -F`.
   - **nginx**: generates the self-signed certificate, renders
     `nginx.conf.template` with `envsubst`, then `exec nginx -g "daemon off;"`.

Useful targets: `make build`, `make ps`, `make logs`, `make stop`, `make
start`, `make restart`, `make down`, `make clean`, `make fclean`, `make re`
(details in README.md / USER_DOC.md).

## 4. Managing containers and volumes

Raw docker commands (equivalent of the Makefile targets):

```sh
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f wordpress
docker compose -f srcs/docker-compose.yml exec mariadb sh      # shell inside
docker compose -f srcs/docker-compose.yml restart nginx
docker compose -f srcs/docker-compose.yml down                 # keep volumes
docker compose -f srcs/docker-compose.yml up -d --force-recreate # remount secrets

docker volume ls                # mariadb_data, wordpress_data
docker volume inspect mariadb_data
docker network ls               # inception
docker network inspect inception

# rebuild a single image + recreate its container
docker compose -f srcs/docker-compose.yml up -d --build nginx

# wipe everything and rebuild (database + site are lost)
make re
```

## 5. Where the data is stored and how it persists

- **Database files**: host directory `/home/yatanagh/data/mariadb`, mounted at
  `/var/lib/mysql` in the mariadb container.
- **Website files**: host directory `/home/yatanagh/data/wordpress`, mounted at
  `/var/www/html` in the wordpress container (nginx mounts the same volume
  read-only).

Persistence semantics:

- `make stop` / `make start` / `make down` / container crash/restart →
  **data preserved**.
- Rebuilding images (`make up --build` / `make re` is NOT needed) →
  data preserved; the entrypoints detect an already-initialized volume
  (`/var/lib/mysql/mysql` exists, `wp-config.php` exists) and skip setup.
- `make clean` → volumes deleted: database and website files gone.
- `make fclean` → additionally removes images and `/home/yatanagh/data`.
- Copying the `/home/yatanagh/data` directory is a full backup of the site.

## 6. Debugging

```sh
make logs                                  # all services
docker logs wordpress                      # first-boot logs of wordpress
docker logs mariadb                        # init SQL errors land here
docker exec wordpress sh -c 'wp core version --path=/var/www/html --allow-root'
docker exec mariadb mariadb -u wpdbuser -p... wordpress_db -e 'SHOW TABLES;'
curl -vk https://yatanagh.42.fr               # TLS + fastcgi round trip
```

Common issues:

- **`make` fails at build** → no internet, or Alpine 3.23 unavailable: check
  `docker pull alpine:3.23` manually. Keep the version pinned (never
  `latest`).
- **wordpress exits after “Waiting for MariaDB”** → mariadb failed to init:
  `docker logs mariadb` (usually a stale volume: `make clean && make`).
- **nginx 502 Bad Gateway** → php-fpm not up or pool not listening on
  `0.0.0.0:9000`: `docker logs wordpress`, `docker exec nginx wget -qO-
  http://wordpress:9000/status` (wget unavailable → check from wordpress:
  `docker exec wordpress sh -c 'echo | nc -q1 mariadb 3306'`).
- **certificate regeneration** → certs are generated once per container
  lifetime; after `make fclean` a new one appears — expected with a
  self-signed setup.
