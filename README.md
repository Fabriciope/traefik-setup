# Traefik v3 — Production Reverse Proxy

A production-ready [Traefik v3](https://traefik.io/) reverse proxy setup using Docker Compose. Handles automatic TLS via Let's Encrypt, HTTP→HTTPS redirection, and a secure dashboard with Basic Auth and security headers.

## What this is

This is a self-contained infrastructure template for running Traefik as a centralized reverse proxy on a Linux server. Once running, any Docker service on the same machine can be exposed to the internet over HTTPS by simply adding a few labels to its `docker-compose.yml` — no manual certificate management needed.

**Typical use case:** a VPS or dedicated server running multiple web services (APIs, apps, admin panels) that all need HTTPS and a single entry point.

## Features

- **Automatic TLS** — certificates issued and renewed by Let's Encrypt via HTTP challenge
- **HTTP → HTTPS redirect** — all plain HTTP traffic is permanently redirected to HTTPS
- **Secure dashboard** — Traefik's built-in UI accessible only over HTTPS, protected by Basic Auth and rate limiting
- **Security headers** — HSTS, X-Frame-Options, Content-Type nosniff, Referrer-Policy, and Permissions-Policy applied globally
- **Health check** — internal ping endpoint on port 8082 for container orchestration
- **IPv4 + IPv6** — both stacks supported out of the box
- **Dynamic config** — other services opt in via Docker labels; Traefik watches for changes without restart
- **File provider** — optional static config files in `traefik/config/` for routes not driven by Docker labels

## Prerequisites

- Docker and Docker Compose v2
- A domain (or subdomain) pointing to your server's public IP — required for Let's Encrypt
- Ports `80` and `443` open in your firewall/security group
- `apache2-utils` (for `htpasswd`) — the setup script installs it automatically if missing

## Quick start

```bash
# 1. Clone the repo
git clone <repo-url>
cd traefik

# 2. Run the one-time setup script
bash setup-traefik-prod.sh
# The script will:
#   - Create the required directory structure
#   - Create acme.json with correct permissions (chmod 600)
#   - Create the Docker network proxy-network
#   - Prompt you to set dashboard credentials (bcrypt via htpasswd)
#   - Copy .env.example → .env

# 3. Edit the environment file
nano .env

# 4. Start Traefik
docker compose up -d
```

## Configuration

### Environment variables (`.env`)

| Variable | Description | Example |
|---|---|---|
| `ACME_EMAIL` | Email for Let's Encrypt notifications | `admin@example.com` |
| `TRAEFIK_DASHBOARD_HOST` | Domain where the Traefik dashboard will be served | `traefik.example.com` |

Copy `.env.example` to `.env` and fill in your values. The `.env` file is git-ignored and must never be committed.

### File structure

```
traefik/
├── acme/
│   └── acme.json          # Let's Encrypt certificate store (auto-generated, chmod 600)
├── auth/
│   └── dashboard_users    # htpasswd credentials for dashboard access
└── config/                # Optional dynamic config files (file provider)
```

All paths under `traefik/acme/` and `traefik/auth/` are git-ignored. You must generate them locally via the setup script.

## Exposing other services

Any Docker service on the `proxy-network` can be proxied by Traefik. Add these labels to its `docker-compose.yml`:

```yaml
services:
  my-app:
    image: my-app:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.example.com`)"
      - "traefik.http.routers.my-app.entrypoints=websecure"
      - "traefik.http.routers.my-app.tls.certresolver=letsencrypt"
      # Optional: apply the shared security-headers middleware
      - "traefik.http.routers.my-app.middlewares=security-headers@docker"
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
```

Traefik picks up the new service automatically — no restart needed.

> **Note on the service port:** if your container exposes multiple ports, or Traefik can't detect the right one automatically, add:
> ```yaml
> - "traefik.http.services.my-app.loadbalancer.server.port=3000"
> ```

## Available shared middlewares

These middlewares are defined on the Traefik container and can be referenced by any service:

| Middleware | Effect |
|---|---|
| `security-headers@docker` | HSTS, frame deny, content-type nosniff, referrer-policy |
| `dashboard-auth@docker` | Basic Auth (dashboard only) |
| `dashboard-ratelimit@docker` | Rate limit: 10 req/s average, burst 20 (dashboard only) |

## Common operations

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs (follow)
docker compose logs -f traefik

# Reload after config changes (e.g. new labels on other containers)
docker compose restart traefik

# Health check
curl -s http://127.0.0.1:8082/ping

# Check container status
docker compose ps
```

## Testing TLS before going to production

Let's Encrypt has a [rate limit](https://letsencrypt.org/docs/rate-limits/) of 5 duplicate certificates per week. To avoid hitting it during tests, use the staging CA:

1. Uncomment the staging server line in `docker-compose.yml`:
   ```yaml
   - "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
   ```
2. Delete the contents of `acme.json` (or recreate it: `> traefik/acme/acme.json`)
3. Start Traefik and verify the certificate is issued (it will be untrusted in the browser — that's expected)
4. Once confirmed, re-comment the staging line, clear `acme.json` again, and restart to get a real certificate

## Security notes

- The Docker socket is mounted **read-only** (`/var/run/docker.sock:ro`)
- `no-new-privileges: true` is set on the container
- The dashboard is not accessible over plain HTTP and is not exposed on port 8080
- Dashboard credentials use bcrypt (cost factor 12) via `htpasswd -B`
- The internal ping/healthcheck port (8082) is not bound to any public interface

## Troubleshooting

**Certificate not being issued**
- Confirm the domain's DNS A record points to this server's public IP
- Ensure port 80 is reachable from the internet (Let's Encrypt HTTP challenge requires it)
- Check logs: `docker compose logs -f traefik | grep -i acme`

**Dashboard not loading**
- Verify `TRAEFIK_DASHBOARD_HOST` in `.env` matches the domain you're accessing
- Confirm DNS is resolving correctly: `dig +short traefik.example.com`

**Service not being picked up by Traefik**
- Check the service is connected to `proxy-network`
- Confirm `traefik.enable=true` label is set
- Inspect Traefik logs for routing errors: `docker compose logs traefik`

**acme.json permission error**
- The file must be owned by root and have mode `600`: `chmod 600 traefik/acme/acme.json`

## License

MIT
