*This project has been created as part of the 42 curriculum by login.*

# Inception

## Description

**Inception** is a system administration project whose goal is to broaden
knowledge of containerization by using Docker. The result is a small
infrastructure hosting a WordPress website, composed of three services, each
running in its own dedicated container:

```
                    Internet
                       |
                 https://login.42.fr (443, TLS 1.2 / 1.3)
                       |
                 ┌───────────┐
                 │   NGINX   │  reverse proxy / TLS endpoint
                 └─────┬─────┘
                       | fastcgi (9000, internal network)
                 ┌─────▼──────┐
                 │ WORDPRESS  │  WordPress + php-fpm (no nginx inside)
                 └─────┬──────┘
                       | mysql (3306, internal network)
                 ┌─────▼──────┐
                 │  MARIADB   │  database server (no nginx inside)
                 └────────────┘

Volumes (named, data stored in /home/login/data on the host):
  wordpress_data -> website files   (/home/login/data/wordpress)
  mariadb_data   -> database files  (/home/login/data/mariadb)
```

Every image is built from the penultimate stable version of Alpine Linux
(`alpine:3.23`) using our own `Dockerfile`s — no prebuilt image (except the
base) is pulled, and the `latest` tag is never used. The whole stack is
managed with **docker compose** driven by the root `Makefile`.

## Project description

### What Docker is used for here

Docker lets each part of the stack (web server, PHP application, database)
run inside an isolated container that packages the application **and** its
runtime configuration. In this project Docker is used to:

- build the three images from scratch (`Dockerfile` per service);
- link the containers through a dedicated bridge network (`inception`);
- persist data through named volumes mapped to `/home/login/data`;
- guarantee the services restart automatically after a crash
  (`restart: always`);
- inject credentials at runtime through **Docker secrets**, so no password
  ever appears in an image or in a `Dockerfile`.

### Sources included in the project

| Path                              | Role                                              |
|-----------------------------------|---------------------------------------------------|
| `Makefile`                        | Entry point: builds and manages the whole stack   |
| `srcs/docker-compose.yml`         | Declares the services, network, volumes, secrets  |
| `srcs/.env`                       | Non-secret configuration (domain, usernames, …)   |
| `secrets/`                        | Passwords, mounted as Docker secrets              |
| `srcs/requirements/nginx/`        | `Dockerfile`, TLS config template, entrypoint     |
| `srcs/requirements/wordpress/`    | `Dockerfile`, php-fpm pool config, entrypoint     |
| `srcs/requirements/mariadb/`      | `Dockerfile`, server config, entrypoint           |

### Main design choices

- **Alpine 3.23** (penultimate stable): tiny images, fast builds, `apk`
  package manager.
- **php-fpm over TCP** (port 9000) instead of a unix socket: nginx and
  WordPress live in different containers, so a socket would require sharing
  yet another volume; TCP on the private network is simpler and safe.
- **WP-CLI** for the first-boot installation of WordPress: downloading the
  core, generating `wp-config.php` and creating the two database users in a
  reproducible, scriptable way.
- **Entrypoints that `exec` the real daemon** (`mariadbd`, `php-fpm83 -F`,
  `nginx -g "daemon off;"`): the service is PID 1, which means signals
  (`docker stop`) are handled correctly. No `tail -f`, `sleep infinity` or
  `while true` anywhere.
- **Docker secrets for passwords**: the secret files in `secrets/` are mounted
  read-only at `/run/secrets/<name>`; the entrypoints read them at startup.
  `.env` only stores non-sensitive values, so it can safely be committed.

### Virtual Machines vs Docker

A **virtual machine** virtualizes hardware: each VM has its own full guest
operating system, kernel, RAM slice and disk, managed by a hypervisor. Startup
takes seconds to minutes and resources are heavy. A **Docker container**
virtualizes only the user space: processes run directly on the host kernel,
isolated by kernel features (namespaces, cgroups). Containers start in
milliseconds, share the host kernel and consume far less memory/disk.

|                  | Virtual machine             | Docker container                    |
|------------------|-----------------------------|-------------------------------------|
| Isolation level  | Hardware-level               | Process-level (kernel namespaces)   |
| Boot time        | Seconds/minutes              | Milliseconds                        |
| Disk footprint   | GBs (full OS)                | MBs (app + dependencies only)       |
| Performance      | Near-native, heavy overhead  | Native, minimal overhead            |
| OS               | Own kernel                   | Shares host kernel                  |

### Secrets vs Environment Variables

Both are ways to pass configuration into a container, but they have different
security properties. **Environment variables** are visible in `docker
inspect`, in the container process list (`ps -e`), get copied into child
processes and often end up logged by accident. **Docker secrets** are files
mounted read-only at `/run/secrets/<name>` at container start; they are not
exposed in the environment, not part of the image layers, and can be excluded
from version control. Secrets are the safer place for passwords; environment
variables remain fine for non-sensitive values (domain name, database name,
usernames). In this project: `.env` = non-secret config, `secrets/` =
passwords.

### Docker Network vs Host Network

With `network_mode: host` the container shares the host network stack: no
isolation, port collisions, and the container can see all host interfaces —
the subject forbids it. The default **bridge** network (here `inception`)
creates a private subnet where containers reach each other by service name
(Docker's embedded DNS resolves `mariadb`, `wordpress`, …), and only the
ports we explicitly publish are exposed to the host (`443` only). It also
supports isolation between projects and is compatible with docker compose
features like `depends_on`.

### Docker Volumes vs Bind Mounts

A **bind mount** mounts an arbitrary host path into the container
(`./host/dir:/container/dir`): the host controls the location, but Docker does
not manage it — which the subject forbids for the two persistent storages.
A **named volume** is an object managed by Docker (`docker volume`). Here the
volumes use the `local` driver with a custom `device` option so their data
physically lives in `/home/login/data` while remaining Docker-managed named
volumes: `docker volume ls` shows `mariadb_data` and `wordpress_data`, exactly
as the subject requires.

## Instructions

Full end-user and developer instructions live in the two dedicated files:

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** — step-by-step setup on a school
  machine, from scratch.
- **[USER_DOC.md](USER_DOC.md)** — how to use and operate the stack.
- **[DEV_DOC.md](DEV_DOC.md)** — how it works internally, for developers.

Quick start (after the one-time setup):

```sh
make        # build the images and start everything
make ps     # check the containers
make logs   # follow the logs
make stop   # stop (data preserved)
make start  # start again
make down   # stop and remove containers (data preserved)
make clean  # down + DELETE the volumes (database and website files)
make fclean # clean + delete images and /home/login/data
make re     # full rebuild from scratch
```

Browse to `https://login.42.fr` (self-signed certificate: accept the warning,
or use `curl -k https://login.42.fr`). Admin panel:
`https://login.42.fr/wp-admin/`.

## Resources

Official documentation used as reference:

- [Docker documentation](https://docs.docker.com/) — images, containers,
  networks, volumes, compose
- [Docker Compose specification](https://docs.docker.com/compose/compose-file/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) and
  [compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [NGINX documentation](https://nginx.org/en/docs/) — server blocks, TLS,
  fastcgi
- [NGINX SSL/TLS configuration](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [php-fpm configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/) —
  `mariadb-install-db`, `--bootstrap`, user management
- [WordPress requirements](https://wordpress.org/about/requirements/)
- [WP-CLI handbook](https://developer.wordpress.org/cli/commands/)
- [Alpine Linux](https://alpinelinux.org/) and
  [Alpine packages](https://pkgs.alpinelinux.org/)
- [42 subject — Inception](en.subject%20.pdf) (v5.3, in this repository)

### How AI was used

AI assistants were used as a documentation accelerator and code reviewer:
- to structure the project and cross-check the subject requirements (services,
  volumes, forbidden patterns);
- to draft the README/USER_DOC/DEV_DOC skeleton and rephrase explanations;
- to sanity-check package names and configuration syntax (nginx, php-fpm,
  MariaDB 11.x) against the official documentation.

Every configuration file and script was read, tested and validated by hand;
no generated block was accepted without being understood and verified against
the official docs.
# ft_inception
