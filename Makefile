# **************************************************************************** #
#                                                                              #
#    Inception — Makefile                                                      #
#                                                                              #
# **************************************************************************** #

COMPOSE       = docker compose
COMPOSE_FILE  = srcs/docker-compose.yml
DATA_DIR      = /home/login/data

GREEN         = \033[0;32m
RED           = \033[0;31m
YELLOW        = \033[0;33m
RESET         = \033[0m

.PHONY: all build up down start stop restart ps logs clean fclean re dirs

all: up

# Create the host directories used by the named volumes.
# Both volumes must live in /home/login/data (see subject).
dirs:
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	@echo "$(GREEN)[OK] Data directories ready: $(DATA_DIR)/{mariadb,wordpress}$(RESET)"

build:
	$(COMPOSE) -f $(COMPOSE_FILE) build

up: dirs
	$(COMPOSE) -f $(COMPOSE_FILE) up -d --build
	@echo "$(GREEN)[OK] Inception is up. Browse to https://login.42.fr$(RESET)"

down:
	$(COMPOSE) -f $(COMPOSE_FILE) down

start: dirs
	$(COMPOSE) -f $(COMPOSE_FILE) start

stop:
	$(COMPOSE) -f $(COMPOSE_FILE) stop

restart:
	$(COMPOSE) -f $(COMPOSE_FILE) restart

ps:
	$(COMPOSE) -f $(COMPOSE_FILE) ps

logs:
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f

# Removes the named volumes: this deletes the database and the website files.
clean: down
	-docker volume rm mariadb_data wordpress_data
	@echo "$(RED)[!] Volumes removed — database and website data deleted.$(RESET)"

# Removes everything: volumes, images and host data directories.
fclean: clean
	-docker image rm nginx:inception wordpress:inception mariadb:inception
	-rm -rf $(DATA_DIR)

re: fclean all
