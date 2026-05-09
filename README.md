# Shared Docker Infrastructure Stack

Shared Docker services for local web development. Runs **Traefik** (reverse proxy), **MariaDB**, **Redis**, **PostgreSQL**, **CloudBeaver** (database manager), and **MailHog** on a shared Docker network (`infra-public`).

App stacks connect to this in **backbone mode** — they run only their app services (web server, PHP, Node) and use this infra stack for database, caching, mail, and reverse proxy. No duplicating services across projects.

---

## Quick Start

```bash
git clone git@github.com:as3k/docker-infra.git
cd docker-infra
make setup    # creates .env + generates TLS cert
make up       # starts everything
```

---

## Services

### Traefik — Reverse Proxy

Routes HTTP/HTTPS traffic to the right container based on hostname. Automatically handles TLS with self-signed certs.

| Detail | Value |
|--------|-------|
| Container | `infra-traefik` |
| Internal | Ports 80 (HTTP), 443 (HTTPS) |
| Host ports | `localhost:80`, `localhost:443` |
| Dashboard | `http://localhost:8888` (HTTP only) |
| Network | `infra-public` |
| TLS certs | Self-signed wildcard for `*.<your-domain>` |

**App stack connection:** Add Traefik labels to your app services. Traefik auto-detects containers on the `infra-public` network and routes based on `Host()` rules.

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.your-domain.dev`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls=true"
  - "traefik.http.services.myapp.loadbalancer.server.port=80"
```

---

### MariaDB — Database

General-purpose relational database. Used by WordPress, Django, Laravel, and most PHP apps.

| Detail | Value |
|--------|-------|
| Container | `infra-mariadb` |
| Internal hostname | `infra-mariadb` |
| Internal port | `3306` |
| Host port | `localhost:3307` (3307 avoids conflict with local MySQL) |
| Network | `infra-public` |
| Data volume | `mariadb-data` (persistent) |

**Default credentials** (from `.env`):
```
Database: appdb
User:     appuser
Password: apppassword
Root:     rootpassword
```

**App stack connection** (`docker-compose.yml`):
```yaml
environment:
  WORDPRESS_DB_HOST: infra-mariadb:3306
  WORDPRESS_DB_USER: ${DB_USER:-appuser}
  WORDPRESS_DB_PASSWORD: ${DB_PASSWORD:-apppassword}
  WORDPRESS_DB_NAME: ${DB_NAME:-appdb}
```

**Direct access** (from host):
```bash
mysql -h 127.0.0.1 -P 3307 -u appuser -papppassword appdb
```

**Creating a new database for a project**:
```bash
mysql -h infra-mariadb -u root -prootpassword -e "CREATE DATABASE myproject;"
mysql -h infra-mariadb -u root -prootpassword -e "GRANT ALL ON myproject.* TO 'appuser'@'%';"
```

Multiple app stacks share the same MariaDB server but use different database names. Use `DB_NAME` in each project's `.env` to isolate them.

---

### PostgreSQL — Database

Relational database for apps that need it (Django, Ruby on Rails, Supabase, etc.).

| Detail | Value |
|--------|-------|
| Container | `infra-postgres` |
| Internal hostname | `infra-postgres` |
| Internal port | `5432` |
| Host port | `localhost:5433` (5433 avoids conflict with local Postgres) |
| Network | `infra-public` |
| Data volume | `postgres-data` (persistent) |
| Image | `postgres:16-alpine` |

**Default credentials** (from `.env`):
```
Database: appdb
User:     appuser
Password: apppassword
```

**App stack connection** (`docker-compose.yml`):
```yaml
environment:
  DATABASE_URL: postgres://${PG_USER:-appuser}:${PG_PASSWORD:-apppassword}@infra-postgres:5432/${PG_NAME:-appdb}
```

**Direct access** (from host):
```bash
psql -h 127.0.0.1 -p 5433 -U appuser -d appdb
```

**Creating a new database for a project**:
```bash
psql -h infra-postgres -U appuser -c "CREATE DATABASE myproject;"
```

---

### Redis — Cache / Queue

In-memory data store for caching, session storage, and message queues.

| Detail | Value |
|--------|-------|
| Container | `infra-redis` |
| Internal hostname | `infra-redis` |
| Internal port | `6379` |
| Host port | None (internal only) |
| Network | `infra-public` |
| Password | `redispassword` (default, from `REDIS_PASSWORD`) |

**App stack connection** (`docker-compose.yml`):
```yaml
environment:
  REDIS_HOST: infra-redis
  REDIS_PASSWORD: ${REDIS_PASSWORD:-redispassword}
```

**Direct access** (from another container on `infra-public`):
```bash
redis-cli -h infra-redis -a redispassword
```

---

### CloudBeaver — Database Manager

Web UI for browsing, querying, and managing both MariaDB and PostgreSQL. Built on the DBeaver engine.

| Detail | Value |
|--------|-------|
| Container | `infra-cloudbeaver` |
| Internal port | `8978` |
| Host port | `localhost:8978` |
| Traefik route | `https://db.<your-domain>` |
| Network | `infra-public` |
| Data volume | `cloudbeaver-data` (persistent — saves connections, queries) |

**First-time setup:**
1. Open `http://localhost:8978` or `https://db.<your-domain>`
2. Create an admin account on first launch
3. Add connections using internal Docker hostnames:

| Database | Host | Port | User | Password |
|----------|------|------|------|----------|
| MariaDB | `infra-mariadb` | 3306 | `appuser` | `apppassword` |
| PostgreSQL | `infra-postgres` | 5432 | `appuser` | `apppassword` |

> Credentials come from your `.env`. Use whatever values you set for `DB_USER` / `PG_USER` etc.

CloudBeaver is on the `infra-public` network, so it can reach all databases by their internal hostname. You can also add connections to databases in attached app stacks if they're on the same network.

---

### MailHog — Email Capture

Catches all outgoing email from your app stacks. No messages actually sent — they appear in the MailHog web UI.

| Detail | Value |
|--------|-------|
| Container | `infra-mailhog` |
| SMTP port | `1025` (internal) |
| HTTP UI port | `8025` (internal) |
| Host access | `https://mail.<your-domain>` (via Traefik) |
| Network | `infra-public` |

**App stack connection:**
```yaml
environment:
  SMTP_HOST: infra-mailhog
  SMTP_PORT: 1025
  # No auth needed — MailHog accepts everything
```

---

## Configuration

All settings go in `.env` (copy from `.env.example`):

| Variable | Default | Description |
|----------|---------|-------------|
| `SITE_DOMAIN` | `dev.local` | Your local dev domain. Used for Traefik routes and TLS certs. |
| `DB_NAME` | `appdb` | Default MariaDB database name |
| `DB_USER` | `appuser` | MariaDB user |
| `DB_PASSWORD` | `apppassword` | MariaDB password |
| `DB_ROOT_PASSWORD` | `rootpassword` | MariaDB root password |
| `PG_NAME` | `appdb` | Default PostgreSQL database name |
| `PG_USER` | `appuser` | PostgreSQL user |
| `PG_PASSWORD` | `apppassword` | PostgreSQL password |
| `REDIS_PASSWORD` | `redispassword` | Redis password |

Change these to match whatever your app stacks expect. All services read from `.env` at runtime.

---

## Ports Reference

| Host Port | Service | Notes |
|-----------|---------|-------|
| 80 | Traefik HTTP (redirects to HTTPS) | Stops if another web server is on :80 |
| 443 | Traefik HTTPS | Stops if another web server is on :443 |
| 3307 | MariaDB | Offset from default 3306 to avoid local MySQL |
| 5433 | PostgreSQL | Offset from default 5432 to avoid local Postgres |
| 8978 | CloudBeaver | Direct web access to DB manager |
| 8888 | Traefik dashboard | HTTP only — shows routes, health, config |

---

## Backbone Mode

App stacks connect to this infra stack instead of running their own services.

**In your app's `docker-compose.yml`:**
```yaml
networks:
  infra-public:
    external: true

services:
  myapp:
    networks:
      - infra-public
    # No MariaDB, no Redis, no Traefik — use the infra stack
```

Then in your app's `.env`:
```env
STACK_MODE=backbone
DB_HOST=infra-mariadb
REDIS_HOST=infra-redis
```

**Do NOT run** your own Traefik, MariaDB, Redis, or MailHog when in backbone mode — they'll conflict with the shared stack.

---

## Multiple Projects

You can run several app stacks against one infra stack. Each project:

1. Uses the same `infra-public` network
2. Gets its own database (create via `CREATE DATABASE project2`)
3. Gets its own Traefik routes (different hostnames)
4. Shares the same Redis, MailHog, and reverse proxy

No need to start/stop the infra stack between projects.

---

## TLS Certificates

`make setup` generates a self-signed wildcard cert for `*.<your-domain>`. Trust it:

- **macOS:** Open Keychain → drag `certs/node.crt` in → trust it for SSL
- **Chrome:** Click "Advanced" → "Proceed anyway"
- **Firefox:** Add security exception

The cert is at `certs/node.crt`. Regenerate anytime with `make setup`.
