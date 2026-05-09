# docker-infra

A shared stack of infrastructure services for local web development. Runs on Docker.

Start it once. Every project on your machine connects to it. No more running five databases because each project has its own.

---

## Quick Start

```bash
git clone git@github.com:as3k/docker-infra.git
cd docker-infra
make setup     # one-time setup
make up        # start everything
```

That's it. Services are running. Connect your app.

---

## What's Inside

Six Docker containers on the `infra-public` network. Your projects join this network and reach services by their container name.

| Service | Container name | What it does |
|---------|---------------|--------------|
| **Traefik** | `infra-traefik` | Routes `*.dev.local` domains to your app containers. Auto-TLS. |
| **MariaDB** | `infra-mariadb` | Database server — WordPress, PHP apps, etc. |
| **PostgreSQL** | `infra-postgres` | Database server — Django, Rails, Supabase, etc. |
| **Redis** | `infra-redis` | Cache / session store. Speeds up your app. |
| **CloudBeaver** | `infra-cloudbeaver` | Web UI for browsing databases — one tool for MariaDB + Postgres. |
| **MailHog** | `infra-mailhog` | Catches outgoing email so you can inspect it without sending real mail. |

---

## Connecting Your App

### From another Docker container (standard approach)

Your app's `docker-compose.yml` joins the shared network and references services by name:

```yaml
networks:
  infra-public:
    external: true

services:
  web:
    build: .
    networks:
      - infra-public
    environment:
      DB_HOST: infra-mariadb
      DB_USER: appuser
      DB_PASSWORD: apppassword
      REDIS_HOST: infra-redis
```

PHP apps like WordPress also need these in `wp-config.php`:

```php
define('DB_HOST', 'infra-mariadb');
define('WP_REDIS_HOST', 'infra-redis');
```

### From your host machine

Services are exposed on non-standard ports to avoid conflicts with local installs:

| Service | Host address | Internal address |
|---------|-------------|-----------------|
| MariaDB | `localhost:3307` | `infra-mariadb:3306` |
| PostgreSQL | `localhost:5433` | `infra-postgres:5432` |
| CloudBeaver | `localhost:8978` | — |
| Traefik dashboard | `localhost:8888` | — |
| Web (via Traefik) | `localhost:80` / `localhost:443` | — |

---

## Default Credentials

| Database | User | Password | Root password |
|----------|------|----------|---------------|
| MariaDB | `appuser` | `apppassword` | `rootpassword` |
| PostgreSQL | `appuser` | `apppassword` | — |
| Redis | — | `redispassword` | — |

MailHog accepts everything — no auth needed.

### CloudBeaver first-time setup

Open `http://localhost:8978`, create an admin account, then add connections using internal hostnames:

| Database | Host | Port | User | Password |
|----------|------|------|------|----------|
| MariaDB | `infra-mariadb` | 3306 | `appuser` | `apppassword` |
| PostgreSQL | `infra-postgres` | 5432 | `appuser` | `apppassword` |

---

## Creating a Database for Your Project

```bash
# MariaDB
mysql -h infra-mariadb -u root -prootpassword -e "CREATE DATABASE myproject;"

# PostgreSQL
psql -h infra-postgres -U appuser -c "CREATE DATABASE myproject;"
```

Run these from any container on the `infra-public` network, or use CloudBeaver's SQL console.

---

## Settings

All config goes in `.env`. Created by `make setup`, edit anytime.

```env
SITE_DOMAIN=dev.local        # Traefik routes use this — *.dev.local
DB_USER=appuser              # MariaDB user
DB_PASSWORD=apppassword      # MariaDB password
PG_USER=appuser              # PostgreSQL user
PG_PASSWORD=apppassword      # PostgreSQL password
REDIS_PASSWORD=redispassword # Redis password
```

Change these if your app expects different values.

---

## Commands

| Command | What it does |
|---------|-------------|
| `make setup` | First run only — creates `.env`, generates TLS cert |
| `make up` | Start all services |
| `make down` | Stop all services |
| `make restart` | Restart everything |
| `make logs` | Follow log output |
| `make ps` | Show running containers |

---

## Common Questions

**Do I need to start this every time I work?**
Leave it running. Start/stop your app projects freely — they all share this stack.

**Port 80 or 443 is already in use.**
Something else is on those ports (another Docker stack, nginx, Apache, etc.). Stop it first, then `make up`.

**TLS cert warnings in the browser.**
`make setup` generates a self-signed cert. Trust `certs/node.crt` in your system keychain to clear them.

**I need a clean database for testing.**
Create a new one (see above) and point your app at it. No restart needed.

**My app already has its own Docker Compose with MariaDB.**
Remove those services from your app's compose file. In backbone mode, your app only needs its web server — the infra stack provides everything else.

**Can I run multiple projects at once?**
Yes. Each project gets its own database and Traefik hostname. Everything else is shared.
