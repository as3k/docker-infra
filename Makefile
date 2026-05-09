.PHONY: up down restart logs setup help

COMPOSE := docker compose -f docker-compose.yml

up: ## Start the shared infra stack
	@echo "Starting shared infra stack..."
	$(COMPOSE) up -d
	@echo "Done. Infra services:"
	@echo "  Traefik    dashboard: http://localhost:8888"
	@echo "  MariaDB    port 3307 (localhost) / infra-mariadb (internal)"
	@echo "  Redis      infra-redis:6379"
	@echo "  MailHog    https://mail.$(shell grep SITE_DOMAIN .env 2>/dev/null | cut -d= -f2 || echo '<your-domain>')"

down: ## Stop the shared infra stack
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

logs: ## Follow logs
	$(COMPOSE) logs -f

ps: ## Show running services
	$(COMPOSE) ps

setup: ## First-time setup — create .env and generate TLS cert
	@echo "=== Infra Stack Setup ==="
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "  .env created from .env.example — review and edit if needed."; \
	fi
	@if command -v openssl >/dev/null 2>&1; then \
		SITE_DOMAIN=$$(grep SITE_DOMAIN .env | cut -d= -f2 || echo "localhost"); \
		openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
			-keyout certs/node.key \
			-out    certs/node.crt \
			-subj "/CN=*.$$SITE_DOMAIN" \
			-addext "subjectAltName=DNS:$$SITE_DOMAIN,DNS:*.$$SITE_DOMAIN" \
			2>/dev/null; \
		echo "  TLS cert generated for *.$$SITE_DOMAIN"; \
	else \
		echo "  openssl not found — generate certs manually:"; \
		echo "    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \\"; \
		echo "      -keyout certs/node.key -out certs/node.crt \\"; \
		echo '      -subj "/CN=*.<your-domain>" \\'; \
		echo '      -addext "subjectAltName=DNS:<your-domain>,DNS:*.<your-domain>"'; \
	fi
	@echo "Setup complete. Run 'make up' to start."

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
