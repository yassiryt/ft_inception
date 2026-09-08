# USER_DOC — Inception user documentation

This document explains, in simple terms, how to use and operate the Inception
stack. You do not need to know Docker internals for the day-to-day commands.

## 1. What services does the stack provide?

The project runs a WordPress website behind three services, each in its own
container:

| Service     | Role                                                          | Port (host)          |
|-------------|---------------------------------------------------------------|----------------------|
| `nginx`     | Web server + TLS. The ONLY public entry point of the stack.   | 443 (HTTPS only)     |
| `wordpress` | WordPress + php-fpm. Serves the site to nginx internally.     | none (internal only) |
| `mariadb`   | Database that stores all WordPress data.                      | none (internal only) |

All communication happens over a private Docker network called `inception`.
From outside, only port **443** is reachable, with **TLSv1.2 or TLSv1.3**.

Two persistent storages (named Docker volumes) keep the data on the host
machine inside `/home/yatanagh/data`:

- `/home/yatanagh/data/mariadb` → the database files;
- `/home/yatanagh/data/wordpress` → the website files.

## 2. Starting and stopping the project

All commands run from the project root (where the `Makefile` is).

| Command       | Effect                                                              |
|---------------|---------------------------------------------------------------------|
| `make`        | Build the images (first time) and start the whole stack.            |
| `make up`     | Same as `make`.                                                     |
| `make stop`   | Stop the containers. Everything is preserved.                       |
| `make start`  | Start the containers again.                                         |
| `make restart`| Restart the containers.                                             |
| `make down`   | Stop and remove the containers. Data (volumes) is preserved.        |
| `make clean`  | `down` + **delete** the volumes → database and site are wiped.      |
| `make fclean` | `clean` + delete the images and `/home/yatanagh/data`. Full reset.     |
| `make re`     | Full reset and rebuild from scratch.                                |

If a container crashes, Docker restarts it automatically
(`restart: always`).

> A container is not a virtual machine: never try to keep it alive with
> `tail -f` or `sleep infinity`. The services themselves are the main
> processes.

## 3. Accessing the website

1. Make sure the domain resolves to your machine. On the school VM, this line
   must be present in `/etc/hosts`:

   ```
   127.0.0.1   yatanagh.42.fr
   ```

   (Replace `login` with your intra username — see SETUP_GUIDE.md.)

2. Open **https://yatanagh.42.fr** in a browser.

3. The certificate is **self-signed**, so the browser will show a security
   warning: accept it / click “Advanced → Proceed”. With curl use:

   ```sh
   curl -k https://yatanagh.42.fr
   ```

4. Administration panel (WordPress dashboard):

   ```
   https://yatanagh.42.fr/wp-admin/
   ```

   Log in with the **administrator** account (see below).

## 4. Locating and managing credentials

Credentials live in two places:

| What            | Where                                                       | Sensitive? |
|-----------------|-------------------------------------------------------------|------------|
| Passwords       | `secrets/*.txt` (one value per file)                        | yes        |
| Usernames, domain, db name | `srcs/.env`                                      | no         |

| File                          | Contains                                      |
|-------------------------------|-----------------------------------------------|
| `secrets/db_root_password.txt`| MariaDB `root` password                        |
| `secrets/db_password.txt`     | Password of the database user used by WordPress|
| `secrets/credentials.txt`     | WordPress **administrator** password           |
| `secrets/wp_user_password.txt`| Password of the second WordPress user          |

To read the current value: `cat secrets/credentials.txt`.

The usernames are defined in `srcs/.env`:

- `WP_ADMIN_USER` (default `supervisor`) → administrator of the site.
- `WP_USER` (default `editor_user`) → second user, role `author`.
- `MYSQL_USER` (default `wpdbuser`) → database account of WordPress.

### Changing a password

1. Edit the corresponding file in `secrets/`.
2. Recreate the containers so the new secret is mounted:

   ```sh
   make down && make up
   ```

   **Database passwords**: the MariaDB accounts are created only when the
   database is initialized. If you change `db_password.txt` or
   `db_root_password.txt` after a first run, run `make clean && make` to
   recreate the database with the new passwords (this deletes all data).

> Never commit `secrets/*.txt` to git — they are ignored by `.gitignore`.
> Credentials in a git repository mean project failure.

## 5. Checking that everything is running correctly

```sh
make ps                       # list the containers and their status
make logs                     # follow the logs of all services

# Website answers over HTTPS?
curl -k -I https://yatanagh.42.fr

# TLS version check
echo | openssl s_client -connect localhost:443 -tls1_2 2>/dev/null | grep -m1 "Protocol"
echo | openssl s_client -connect localhost:443 -tls1_3 2>/dev/null | grep -m1 "Protocol"
```

Inside the containers:

```sh
# Database is alive?
docker exec mariadb mariadb-admin ping -u wpdbuser -p$(cat secrets/db_password.txt)

# WordPress sees its database?
docker exec wordpress wp db check --path=/var/www/html --allow-root

# The two users exist in the WordPress database?
docker exec mariadb mariadb -u wpdbuser -p$(cat secrets/db_password.txt) \
    -e "USE wordpress_db; SELECT user_login FROM wp_users;"

# php-fpm workers are running
docker exec wordpress ps aux | grep php-fpm
```

All good if: `make ps` shows the three containers `Up`, the curl command
returns HTML, and the `wp_users` query shows two rows.
