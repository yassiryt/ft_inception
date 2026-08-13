# SETUP_GUIDE — Installing Inception on a school machine

Step-by-step plan, from an empty VM to a working WordPress site.
Follow the steps in order. Commands run in a terminal.

> Placeholder: this guide uses `login` for the intra username. Replace it
> with YOUR username everywhere (`login.42.fr` → `you.42.fr`,
> `/home/login/data` → `/home/you/data`).

---

## Step 1 — Get a virtual machine

Open the intra (profile → Settings → session), start a 42 session and launch
an Ubuntu VM. Log in as your user (`login`). This project is only supported
on a VM, not on your host machine.

## Step 2 — Install Docker + compose plugin

```sh
sudo apt-get update

# Docker Engine (official repo)
curl -fsSL https://get.docker.com | sudo sh

# docker compose v2 plugin
sudo apt-get install -y docker-compose-plugin

# allow your user to run docker without sudo
sudo usermod -aG docker $USER
newgrp docker            # apply the group now (or log out/in)

docker --version
docker compose version   # must print a version
```

If your session VM already ships Docker (some campus images do), just verify
the two version commands above.

## Step 3 — Clone the project

```sh
cd ~
git clone <your-repo-url> inception   # e.g. from the intra git server
cd inception
```

## Step 4 — Replace the placeholder username

The project ships with the placeholder `login`. Replace it in exactly these
places:

1. `srcs/.env` → `DOMAIN_NAME=login.42.fr` becomes `you.42.fr` (and the two
   WordPress email addresses if you like).
2. `Makefile` → `DATA_DIR = /home/login/data` becomes `/home/you/data`.
3. `srcs/docker-compose.yml` → the two `device:` lines under `volumes:`
   become `/home/you/data/mariadb` and `/home/you/data/wordpress`.

```sh
# quick way (check the result afterwards!)
sed -i 's|/home/login/data|/home/you/data|g' Makefile srcs/docker-compose.yml
sed -i 's|login\.42\.fr|you.42.fr|g' srcs/.env
```

Also edit the first line of `README.md` (the italic line) with your login.

## Step 5 — Fill the secrets

```sh
cd secrets
echo "type-a-strong-root-password-here"   > db_root_password.txt
echo "type-a-strong-db-user-password"     > db_password.txt
echo "type-a-strong-wp-admin-password"    > credentials.txt
echo "type-a-strong-second-user-password" > wp_user_password.txt
cd ..
```

Each file contains exactly one line: the password. They are git-ignored —
never commit them.

Optional: adjust usernames / title in `srcs/.env`
(`WP_ADMIN_USER` must NOT contain “admin”, subject rule — the default
`supervisor` is fine).

## Step 6 — Point the domain to your local IP

```sh
sudo nano /etc/hosts
```

Add this line and save:

```
127.0.0.1   you.42.fr
```

## Step 7 — Build and run

```sh
make
```

First run downloads the Alpine base image, builds the three images and
starts the stack. This can take a few minutes. Then:

```sh
make ps     # the 3 containers must be "Up"
```

## Step 8 — Verify everything

```sh
# 1. containers
docker ps

# 2. website answers over TLS 1.2 / 1.3
curl -k https://you.42.fr | head

# 3. admin panel exists (and log in with credentials from secrets/)
#    browser: https://you.42.fr/wp-admin/
```

Browser will warn about the self-signed certificate → accept it.

## Step 9 — What to do when you come back (data persists)

```sh
make start     # if you stopped it
make           # rebuild if images are missing
```

## Troubleshooting

| Symptom                              | Fix                                                              |
|--------------------------------------|------------------------------------------------------------------|
| `docker: permission denied`          | `newgrp docker` (or log out/in) after `usermod -aG docker`       |
| Build fails downloading packages     | No internet in the VM → check network, retry                     |
| `make` OK but wordpress exits        | `docker logs wordpress` (usually DB not ready or bad secret)     |
| nginx returns 502                    | `docker logs wordpress` — php-fpm must listen on 0.0.0.0:9000    |
| Port 443 already in use              | Another service uses it → `sudo lsof -i :443`, stop it           |
| Changed a DB password, site broken   | `make clean && make` (recreates the database with new passwords) |
| Reset everything                     | `make fclean` then start again from Step 7                       |

## Full checklist (used by evaluators)

- [ ] All files under `srcs/`, Makefile at root, `README.md` first line italic with my login
- [ ] `make` builds and starts 3 containers: nginx, wordpress, mariadb
- [ ] Images built from `alpine:3.23` (no pulled prebuilt images, no `latest`)
- [ ] Only port 443 published; `curl -k https://you.42.fr` works
- [ ] TLSv1.2/1.3 only (`openssl s_client -tls1_2` and `-tls1_3` succeed, `-tls1_1` fails)
- [ ] Volumes: `docker volume ls` shows `mariadb_data` + `wordpress_data`
- [ ] Data in `/home/you/data/{mariadb,wordpress}`
- [ ] `docker network ls` shows `inception` (bridge, no `host`/`links`)
- [ ] `restart: always` — stop a container and it comes back
- [ ] No `tail -f` / `sleep infinity` / `while true` in entrypoints or commands
- [ ] 2 users in the WordPress DB, admin username without “admin”
- [ ] No password in Dockerfiles; `.env` + `secrets/` used; secrets git-ignored
- [ ] `USER_DOC.md` and `DEV_DOC.md` present at the root
