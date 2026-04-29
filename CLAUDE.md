# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Traefik v3 reverse proxy configured for production use with Docker Compose. Handles automatic TLS via Let's Encrypt (HTTP challenge), HTTP→HTTPS redirection, and dashboard access with Basic Auth.

## Initial Setup (run once)

```bash
# Run the setup script — creates directories, acme.json, proxy-network, and dashboard credentials
bash setup-traefik-prod.sh
```

Manual equivalent:
```bash
mkdir -p ./traefik/acme ./traefik/auth ./traefik/config
touch ./traefik/acme/acme.json && chmod 600 ./traefik/acme/acme.json
docker network create proxy-network
echo $(htpasswd -nBC 12 admin) > ./traefik/auth/dashboard_users
```

## Operations

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Logs
docker compose logs -f traefik

# Reload config (e.g. after label changes on other containers)
docker compose restart traefik

# Health check
curl -s http://127.0.0.1:8082/ping
```

## Architecture

- **Entrypoints**: `:80` (HTTP, always redirects to HTTPS), `:443` (HTTPS), `:8082` (internal ping/healthcheck only)
- **TLS resolver**: `letsencrypt` using HTTP challenge on the `web` entrypoint; certificates stored in `./traefik/acme/acme.json`
- **Dashboard**: exposed at `${TRAEFIK_DASHBOARD_HOST}` (HTTPS only) behind `dashboard-auth` (Basic Auth) and `security-headers` middlewares
- **Docker provider**: watches containers on the `proxy-network` external network; containers must opt in with `traefik.enable=true`

## Key Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | All Traefik configuration via CLI flags and labels |
| `.env` | `ACME_EMAIL` and `TRAEFIK_DASHBOARD_HOST` |
| `traefik/acme/acme.json` | Let's Encrypt certificate store — must be `chmod 600` |
| `traefik/auth/dashboard_users` | htpasswd-format credentials (bcrypt, `-B` flag) |

## Exposing Other Services

Add these labels to any service on `proxy-network`:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<name>.rule=Host(`example.com`)"
  - "traefik.http.routers.<name>.entrypoints=websecure"
  - "traefik.http.routers.<name>.tls.certresolver=letsencrypt"
  # optional: reference middlewares defined on the traefik container
  - "traefik.http.routers.<name>.middlewares=security-headers@docker"
networks:
  - proxy-network
```

## Testing TLS Without Hitting Rate Limits

Uncomment the staging CA server line in `docker-compose.yml` before first run:
```
- "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
```
Remember to delete `acme.json` contents and restart when switching between staging and production.
