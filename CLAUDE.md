# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Traefik v3 reverse proxy with two environments:

- **`production/`** — VPS/server setup with TLS via Let's Encrypt, HTTPS-only dashboard behind Basic Auth, security headers, rate limiting, and IPv4+IPv6 support.
- **`development/`** — Local dev setup with HTTP only, no auth, dashboard exposed on port 8080, debug logging.

Both environments share the same `proxy-network` Docker network. Other projects connect to that network and use `traefik.enable=true` labels to be picked up automatically.

## Root script

```bash
./traefik.sh <dev|prod> [docker compose command]

# Examples
./traefik.sh dev               # docker compose up -d in development/
./traefik.sh prod              # docker compose up -d in production/
./traefik.sh dev logs -f
./traefik.sh prod down
```

## Initial setup (run once per environment)

```bash
# Development
bash development/setup-traefik-dev.sh

# Production
bash production/setup-traefik-prod.sh
```

## Operations (per environment)

```bash
# cd into the environment directory first, then use docker compose normally:
cd development && docker compose up -d
cd development && docker compose logs -f traefik
cd development && docker compose restart

# Or use the root script:
./traefik.sh dev logs -f
./traefik.sh prod restart
```

## Architecture

### Production (`production/`)

- **Entrypoints**: `:80` (HTTP → HTTPS redirect), `:443` (HTTPS), `:8082` (internal ping)
- **TLS**: Let's Encrypt via HTTP challenge; certificates in `production/traefik/acme/acme.json`
- **Dashboard**: `${TRAEFIK_DASHBOARD_HOST}` (HTTPS only) behind Basic Auth + security headers + rate limit
- **Env vars**: `ACME_EMAIL`, `TRAEFIK_DASHBOARD_HOST` — set in `production/.env`

### Development (`development/`)

- **Entrypoints**: `:80` (HTTP only, no TLS)
- **Dashboard**: `http://localhost:8080/dashboard/` (direct, no auth) and `http://traefik.local/dashboard/` (requires `/etc/hosts` entry)
- **Logs**: DEBUG level, plain text format
- **No auth, no rate limit, no security headers**

## Key files

| File | Purpose |
|---|---|
| `traefik.sh` | Root script — runs docker compose in the right environment directory |
| `production/docker-compose.yml` | Production Traefik config (TLS, auth, headers) |
| `production/.env` | `ACME_EMAIL` and `TRAEFIK_DASHBOARD_HOST` — git-ignored |
| `production/traefik/acme/acme.json` | Let's Encrypt certificate store — must be `chmod 600` |
| `production/traefik/auth/dashboard_users` | htpasswd credentials (bcrypt, `-B` flag) — git-ignored |
| `development/docker-compose.yml` | Development Traefik config (HTTP, no auth) |

## Exposing other services

### Production labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<name>.rule=Host(`example.com`)"
  - "traefik.http.routers.<name>.entrypoints=websecure"
  - "traefik.http.routers.<name>.tls.certresolver=letsencrypt"
  # optional: apply shared security headers
  - "traefik.http.routers.<name>.middlewares=security-headers@docker"
networks:
  - proxy-network
```

### Development labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<name>.rule=Host(`myapp.localhost`)"
  - "traefik.http.routers.<name>.entrypoints=web"
networks:
  - proxy-network
```

> `.localhost` domains resolve to `127.0.0.1` natively in the browser — no `/etc/hosts` changes needed.

## Development dashboard via traefik.local

To use `http://traefik.local` (instead of `localhost:8080`), add to `/etc/hosts`:

```
127.0.0.1 traefik.local
```

## Testing TLS without hitting rate limits (production)

Uncomment the staging CA server line in `production/docker-compose.yml`:
```
- "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
```
Delete `production/traefik/acme/acme.json` contents and restart when switching between staging and production.
