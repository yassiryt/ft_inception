# Secrets folder

This folder holds the sensitive values of the stack. Each file contains
**exactly one line: the secret value itself** (no comments, no newline at the
end). They are mounted read-only into the containers at `/run/secrets/<name>`
by docker-compose and are never baked into the images.

## Required files

| File                   | Used by          | Secret it holds                                   |
|------------------------|------------------|---------------------------------------------------|
| `db_root_password.txt` | mariadb          | Password of the MariaDB `root` user               |
| `db_password.txt`      | mariadb, wordpress | Password of the MariaDB user used by WordPress  |
| `credentials.txt`      | wordpress        | Password of the WordPress **administrator**       |
| `wp_user_password.txt` | wordpress        | Password of the second WordPress user             |

## How to fill them

Open each file with any text editor and replace the placeholder line with a
strong password. Example:

```sh
echo "MyStr0ngP@ssw0rd" > secrets/db_password.txt
```

## Rules

- The `*.txt` files in this folder are ignored by git (see root `.gitignore`).
  Never `git add -f` them: credentials in a git repository mean project failure.
- If you change a secret **after** the containers were started, the change is
  only applied after recreating the containers:

  ```sh
  make re    # or: docker compose -f srcs/docker-compose.yml up -d --force-recreate
  ```

- Changing the database passwords after the database has been initialized
  requires removing the database volume as well (`make clean`, then `make`),
  because the users are created only on the first initialization.
