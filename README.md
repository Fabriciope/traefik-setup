# Traefik v3 — Reverse Proxy (Production + Development)
👉[Artigo completo sobre o assunto.](https://fabriciopa.com.br/artigos/traefik-v3-docker-producao)
<br><br>
A [Traefik v3](https://traefik.io/) reverse proxy setup using Docker Compose, with separate configurations for **production** (VPS with TLS) and **development** (local, HTTP only).

## Repository structure

```
traefik/
├── traefik.sh          # root script — manage either environment
├── production/         # VPS setup: TLS, HTTPS, Basic Auth, security headers
│   ├── docker-compose.yml
│   ├── .env.example
│   └── setup-traefik-prod.sh
└── development/        # local dev: HTTP only, no auth, debug logs
    ├── docker-compose.yml
    ├── .env.example
    └── setup-traefik-dev.sh
```

---

## Root script

```bash
./traefik.sh <dev|prod> [docker compose command]
```

| Command | What it does |
|---|---|
| `./traefik.sh dev` | `docker compose up -d` in `development/` |
| `./traefik.sh prod` | `docker compose up -d` in `production/` |
| `./traefik.sh dev logs -f` | Follow logs in dev |
| `./traefik.sh prod down` | Stop production |
| `./traefik.sh dev restart` | Restart dev |

---

## Development environment

Designed for local use — no domain, no certificates, no passwords required.

### Quick start

```bash
# 1. One-time setup (creates the Docker network)
bash development/setup-traefik-dev.sh

# 2. Start
./traefik.sh dev
```

### Dashboard

| URL | How |
|---|---|
| `http://localhost:8080/dashboard/` | Always works, no setup needed |
| `http://traefik.local/dashboard/` | Requires `/etc/hosts` entry (see below) |

**Optional — access via `traefik.local`:**

```bash
echo "127.0.0.1 traefik.local" | sudo tee -a /etc/hosts
```

### Exposing a service in development

```yaml
services:
  my-app:
    image: my-app:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.my-app.entrypoints=web"
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
```

> `.localhost` domains resolve to `127.0.0.1` natively in most browsers and operating systems — no `/etc/hosts` changes needed.

---

## Production environment

For a Linux VPS with a public domain. Handles automatic TLS via Let's Encrypt, HTTP→HTTPS redirection, and a secure dashboard behind Basic Auth.

### Prerequisites

- Docker and Docker Compose v2
- A domain (or subdomain) pointing to your server's public IP
- Ports `80` and `443` open in your firewall
- `apache2-utils` (for `htpasswd`) — the setup script installs it if missing

### Quick start

```bash
# 1. Run the one-time setup (creates directories, acme.json, network, credentials)
bash production/setup-traefik-prod.sh

# 2. Edit environment variables
nano production/.env

# 3. Start
./traefik.sh prod
```

### Environment variables (`production/.env`)

| Variable | Description | Example |
|---|---|---|
| `ACME_EMAIL` | Email for Let's Encrypt notifications | `admin@example.com` |
| `TRAEFIK_DASHBOARD_HOST` | Domain for the Traefik dashboard | `traefik.example.com` |

Copy `production/.env.example` to `production/.env` and fill in your values. The `.env` file is git-ignored and must never be committed.

### Exposing a service in production

```yaml
services:
  my-app:
    image: my-app:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.example.com`)"
      - "traefik.http.routers.my-app.entrypoints=websecure"
      - "traefik.http.routers.my-app.tls.certresolver=letsencrypt"
      # Optional: shared security headers middleware
      - "traefik.http.routers.my-app.middlewares=security-headers@docker"
    networks:
      - proxy-network

networks:
  proxy-network:
    external: true
```

### Available shared middlewares (production)

| Middleware | Effect |
|---|---|
| `security-headers@docker` | HSTS, frame deny, content-type nosniff, referrer-policy |
| `dashboard-auth@docker` | Basic Auth (dashboard only) |
| `dashboard-ratelimit@docker` | Rate limit: 10 req/s average, burst 20 (dashboard only) |

### Testing TLS before going live

Let's Encrypt has a [rate limit](https://letsencrypt.org/docs/rate-limits/) of 5 duplicate certificates per week. Use the staging CA during tests:

1. Uncomment the staging line in `production/docker-compose.yml`:
   ```
   - "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
   ```
2. Clear `production/traefik/acme/acme.json` and restart
3. Verify the certificate is issued (it will be untrusted — expected in staging)
4. Re-comment the line, clear `acme.json` again, restart to get a real certificate

### Common operations

```bash
./traefik.sh prod logs -f traefik
./traefik.sh prod restart
./traefik.sh prod down

# Health check (production)
curl -s http://127.0.0.1:8082/ping
```

---

## Troubleshooting

**Certificate not being issued (production)**
- Confirm the domain's DNS A record points to this server's IP
- Ensure port 80 is reachable from the internet (HTTP challenge requires it)
- Check logs: `./traefik.sh prod logs -f traefik | grep -i acme`

**Dashboard not loading (production)**
- Verify `TRAEFIK_DASHBOARD_HOST` in `production/.env` matches the domain you're accessing
- Confirm DNS: `dig +short your-domain.com`

**Service not picked up by Traefik**
- Check the service is connected to `proxy-network`
- Confirm `traefik.enable=true` label is set
- Check logs: `./traefik.sh dev logs traefik`

**acme.json permission error (production)**
- The file must have mode `600`: `chmod 600 production/traefik/acme/acme.json`

## Security notes (production)

- Docker socket is mounted **read-only** (`/var/run/docker.sock:ro`)
- `no-new-privileges: true` is set on the container
- Dashboard is not accessible over plain HTTP and not exposed on port 8080
- Dashboard credentials use bcrypt (cost factor 12) via `htpasswd -B`
- The internal ping port (8082) is not bound to any public interface

## License

MIT
