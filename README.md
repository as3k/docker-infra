# MemberSplash Shared Infrastructure Stack

Shared Docker services for the MemberSplash development environment. Provides Traefik (reverse proxy), MariaDB, Redis, and MailHog on the `infra-public` Docker network.

App stacks (like `docker-msdev`) connect to this in **backbone mode** — they run only their app services (WordPress, WP-CLI, PHPMyAdmin, Node) and use this infra stack for database, caching, mail, and reverse proxy.

## Quick Start

```bash
# 1. Clone
git clone git@github.com:zacharyg-ms/docker-infra.git
cd docker-infra

# 2. First-time setup
make setup

# 3. Start
make up
```

## Services

| Service       | Hostname        | Internal Port | External    |
|---------------|-----------------|---------------|-------------|
| Traefik       | infra-traefik   | 80/443        | localhost:80/443 |
| MariaDB       | infra-mariadb   | 3306          | localhost:3307 |
| Redis         | infra-redis     | 6379          | —           |
| MailHog       | infra-mailhog   | 8025 (HTTP)   | via Traefik |

## Commands

```bash
make setup    # First-time setup (.env + TLS certs)
make up       # Start all services
make down     # Stop all services
make restart  # Restart all services
make logs     # Follow logs
make ps       # Show running containers
```

## Connecting an App Stack (Backbone Mode)

1. Make sure this infra stack is running (`make up`).
2. In your app stack (e.g., `docker-msdev`), run `setup.sh` and choose **backbone mode**.
3. The app services will auto-detect the infra services via the `infra-public` network.

## Network

All services connect to the `infra-public` bridge network. App stacks join this network (as `external: true`) to reach shared services.

## TLS

A self-signed wildcard certificate is generated during `make setup` for `*.<your-domain>` (default: `*.msdev.com`). Trust the `certs/node.crt` in your system keychain to avoid browser warnings.

## Ports

Traefik binds to host ports 80 and 443. If you have other services on those ports (like standalone docker-msdev), they'll conflict — stop one stack before starting the other.

MariaDB exposes port 3307 on localhost to avoid conflicting with a local MySQL/MariaDB install.
