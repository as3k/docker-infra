# Shared Docker Infrastructure Stack

Shared Docker services for local web development. Provides **Traefik** (reverse proxy with automatic TLS), **MariaDB**, **Redis**, and **MailHog** on a shared Docker network (`infra-public`).

App stacks (like WordPress multisite dev environments) connect to this in **backbone mode** — they run only their app services (web server, PHP, Node) and use this infra stack for database, caching, mail, and reverse proxy.

---

## Why Use This?

- **Single Traefik instance** — one reverse proxy handles routing for multiple projects. No port conflicts.
- **Shared database server** — MariaDB runs once. Each project gets its own database.
- **Shared Redis** — one cache server for all projects.
- **Shared MailHog** — capture all outgoing email in one place.
- **Backbone pattern** — app stacks are lighter; they don't duplicate infra services.

---

## Quick Start

```bash
# 1. Clone
git clone git@github.com:as3k/docker-infra.git
cd docker-infra

# 2. First-time setup (generates .env + TLS certs)
make setup

# 3. Start
make up
```

---

## Services

| Service | Container Name | Internal Hostname | Port(s) | External Access |
|---------|---------------|-------------------|---------|-----------------|
| Traefik  | `infra-traefik`  | — | 80 / 443 | `localhost:80`, `localhost:443`, `localhost:8888` (dashboard) |
| MariaDB  | `infra-mariadb`  | `infra-mariadb` | 3306 | `localhost:3307` |
| Redis    | `infra-redis`    | `infra-redis` | 6379 | — (internal only) |
| PostgreSQL | `infra-postgres` | `infra-postgres` | 5432 | `localhost:5433` |
| MailHog  | `infra-mailhog`  | — | 8025 (HTTP) | `https://mail.<your-domain>` (via Traefik) |

---

## Commands

```bash
make setup    # First-time setup (.env + TLS certs)
make up       # Start all services
make down     # Stop all services
make restart  # Restart all services
make logs     # Follow logs
make ps       # Show running containers
```

---

## Connecting an App Stack (Backbone Mode)

1. Make sure this infra stack is running: `make up`
2. In your app stack, configure it to use **backbone mode** (connects to the `infra-public` network)
3. The app services will auto-detect the infra services via the internal hostnames (`infra-mariadb`, `infra-redis`)

All services connect to the `infra-public` Docker bridge network. App stacks join this network (declared as `external: true`) to reach shared services.

---

## Configuration

Copy `.env.example` → `.env` and set your domain:

```env
SITE_DOMAIN=your-domain.dev
```

A self-signed wildcard TLS certificate is generated during `make setup` for `*.<your-domain>`. Trust the `certs/node.crt` in your system keychain to avoid browser warnings.

---

## Ports

| Host Port | Service | Notes |
|-----------|---------|-------|
| 80 | Traefik HTTP → redirects to HTTPS | Conflicts with other web servers |
| 443 | Traefik HTTPS | Conflicts with other web servers |
| 3307 | MariaDB | 3307 avoids conflict with local MySQL |
| 5433 | PostgreSQL | 5433 avoids conflict with local Postgres |
| 8888 | Traefik dashboard | HTTP only |

If you have other services on ports 80/443 (like a standalone Docker stack running Traefik), stop them before starting this stack.

---

## Multiple App Stacks

You can connect multiple app stacks to a single infra stack. Each app stack needs:

1. Access to the `infra-public` network (declared as `external: true`)
2. Its own database (create via MariaDB client or app setup)
3. Its own Traefik routes (using Docker Compose labels with unique hostnames)

App stacks must **not** run their own Traefik, MariaDB, Redis, or MailHog when in backbone mode — those services would conflict with this shared stack.
