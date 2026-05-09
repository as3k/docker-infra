# docker-infra

A shared stack of infrastructure services for local web development. Runs on Docker. Gives you a database, cache, email catcher, reverse proxy, and database admin UI — all in one place.

Instead of every project running its own copy of these services, they all share this one stack. Start it once, use it from any project.

---

## What's Inside

| Service | What it's for |
|---------|---------------|
| **Traefik** | Routes web traffic — `myapp.dev.local` goes to your app, `pma.dev.local` goes to phpMyAdmin, etc. |
| **MariaDB** | Database server — the standard for WordPress, PHP apps, etc. |
| **PostgreSQL** | Database server — for Django, Rails, Supabase-style apps, etc. |
| **Redis** | Cache / session store — makes your app faster. |
| **CloudBeaver** | Web UI for browsing and querying databases — one tool for both MariaDB and Postgres. |
| **MailHog** | Catches outgoing email so you can see it without actually sending anything. |

---

## Quick Start

```bash
git clone git@github.com:as3k/docker-infra.git
cd docker-infra
make setup     # one-time setup (creates .env + TLS cert)
make up        # start everything
```

That's it. After `make up`, the services are running. Connect your app to them.

---

## How App Stacks Connect

Projects using this stack run in **backbone mode** — they skip running their own database, Redis, Traefik, etc., and connect to this shared stack instead.

**Your app needs two things:**

1. A `docker-compose.yml` with the `infra-public` network declared as external
2. Environment variables pointing to the shared services

```yaml
# docker-compose.yml — in your app project
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

Start this infra stack once (`make up`). Start/stop your app projects independently — they share the same database, cache, and proxy.

---

## Connecting from Outside Docker

Services are exposed on non-standard host ports so they don't conflict with anything you already have installed locally:

| Service | Host access | Why that port |
|---------|-------------|---------------|
| MariaDB | `localhost:3307` | Avoids conflict with local MySQL (3306) |
| PostgreSQL | `localhost:5433` | Avoids conflict with local Postgres (5432) |
| CloudBeaver | `localhost:8978` | Web UI |
| MailHog | `https://mail.<your-domain>` | Via Traefik |

Web services (Traefik-routed) use `localhost:80` and `localhost:443` — standard web ports.

---

## Creating a Database for Your Project

```bash
# MariaDB
mysql -h infra-mariadb -u root -prootpassword -e "CREATE DATABASE myproject;"

# PostgreSQL
psql -h infra-postgres -U appuser -c "CREATE DATABASE myproject;"
```

Run these from any container on the `infra-public` network (or from CloudBeaver's SQL console).

---

## Settings

All config lives in `.env` (created by `make setup`). Key variables:

| Variable | Default | What it is |
|----------|---------|------------|
| `SITE_DOMAIN` | `dev.local` | Your local domain — all Traefik routes use this |
| `DB_USER` / `DB_PASSWORD` | `appuser` / `apppassword` | MariaDB login |
| `PG_USER` / `PG_PASSWORD` | `appuser` / `apppassword` | PostgreSQL login |
| `REDIS_PASSWORD` | `redispassword` | Redis password |

Change these to match whatever your projects expect.

---

## Default Credentials

| Database | User | Password | Root password |
|----------|------|----------|---------------|
| MariaDB | `appuser` | `apppassword` | `rootpassword` |
| PostgreSQL | `appuser` | `apppassword` | — |

CloudBeaver: Create an admin account on first launch at `http://localhost:8978`, then add connections using the internal hostnames `infra-mariadb:3306` and `infra-postgres:5432`.

---

## Commands Reference

```bash
make setup    # First run only — creates .env + TLS certificate
make up       # Start all services
make down     # Stop everything
make restart  # Restart all services
make logs     # See what's happening (follow log output)
make ps       # Show which containers are running
```

---

## Tips

- **Start once, use everywhere.** Leave this stack running. Start/stop your app projects freely.
- **Need a fresh database?** Just create a new one in MariaDB/Postgres. No need to restart anything.
- **Port conflicts?** If port 80/443 is already in use, stop whatever's on them first (other Docker stacks, nginx, Apache, etc.).
- **TLS warnings?** `make setup` generates a self-signed cert. Trust `certs/node.crt` in your system keychain to make the warnings go away.
- **Multiple projects?** Each project gets its own database and Traefik hostname. Everything else is shared.
- **Don't run two Traefiks.** If you use this stack, make sure your app projects don't include their own Traefik or database services in backbone mode.
