# Local Development Setup - Complete Guide

This documents every step to get InvenioRDM running locally via Docker
Compose, from a fresh clone to a working instance in a browser.

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Docker | 20.10+ | `docker --version` |
| Docker Compose | v2+ (bundled with Docker Desktop) | `docker compose version` |
| Stack Car | latest | `gem install stack_car` then `sc proxy up` |

Python, Node.js, pipenv, and all other dependencies run inside Docker
containers. Stack Car provides a shared Traefik proxy for TLS termination
with `localhost.direct` certificates.

**Docker Desktop memory**: Allocate at least **6 GB** of RAM in Docker
Desktop settings (Preferences > Resources). OpenSearch alone needs 2 GB.

---

## Setup

### Step 1: Clone and enter the project

```bash
git clone git@github.com:notch8/invenioup.git
cd invenioup
```

### Step 2: Start the Stack Car proxy

```bash
sc proxy up
```

This starts Traefik on the shared `stackcar` Docker network with
`localhost.direct` TLS certificates. It only needs to be done once per
Docker Desktop session.

### Step 3: Environment file

```bash
cp .env.example .env
# Edit .env if you change passwords or secrets; defaults match local Docker services.
```

Docker Compose reads `.env` for variable substitution and passes it into the
Invenio containers. Without this file, `docker compose` will fail on startup.

### Step 4: Build and start everything

```bash
docker compose up --build -d
```

Alternatively, build images first, then start:

```bash
docker build -t invenioup:latest .
docker build -t invenioup-frontend:latest ./docker/nginx/
docker compose up -d
```

This builds two images and starts all services:
- `invenioup` -- the InvenioRDM application (Python deps + JS assets)
- `invenioup-frontend` -- the Nginx uwsgi reverse proxy (behind Traefik)

If `Pipfile.lock` doesn't exist, it will be **generated inside the Docker
build** automatically. No host Python/pipenv needed.

The first build takes **10-20 minutes** (installing ~300 Python packages,
building webpack assets). Subsequent builds are cached.

This starts all services and **automatically initializes on first run**:
- Creates the database tables and search indexes
- Sets up admin roles and permissions
- Loads vocabularies and fixtures (resource types, licenses, etc.)
- Creates an admin user (defaults: `INVENIO_ADMIN_EMAIL` / `INVENIO_ADMIN_PASSWORD` from `.env`)
- Loads demo records

On subsequent runs, the entrypoint detects the DB is already initialized
and skips straight to starting the application.

Wait ~60 seconds for all services to be healthy, especially on first run.

```bash
# Verify all containers are running
docker compose ps

# Check OpenSearch is ready (should return a JSON response)
curl -s http://127.0.0.1:9200 | head -5

# Watch the init progress on first run
docker compose logs -f web-ui web-api worker
```

### Step 5: Access the instance

Open **https://invenioup.localhost.direct** in your browser.

`localhost.direct` is a public DNS name that resolves to `127.0.0.1`,
letting Traefik route by hostname. If the Stack Car cert is trusted in
your system keychain, you'll get a green lock. Otherwise, accept the
self-signed cert warning on first visit.

Login with the admin credentials from your `.env` (see `INVENIO_ADMIN_EMAIL` and `INVENIO_ADMIN_PASSWORD`).

The **Traefik dashboard** is available at **https://traefik.localhost.direct**
for inspecting routes, services, and middleware.

### Step 6: (Optional) Create an S3 bucket in MinIO

For file uploads to work locally:

```bash
# Use the MinIO web console at http://127.0.0.1:9001
# Login with MINIO_ROOT_USER / MINIO_ROOT_PASSWORD from your .env
# Create a bucket called "default"
```

---

## Stopping and Restarting

```bash
# Stop everything (keeps data)
docker compose down

# Stop and destroy all data (full reset -- next `up` will re-init)
docker compose down -v

# Restart (after a stop, no rebuild needed)
docker compose up -d
```

---

## Testing

```bash
# Smoke tests (curl-based health checks)
./scripts/smoke-test.sh

# Playwright e2e tests
cd tests/e2e && npm install && npx playwright install chromium
npx playwright test
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Port 5432 already in use | We map Postgres to host port 5433, but if you still have conflicts check `docker compose ps` for port maps |
| OpenSearch won't start | Increase Docker Desktop memory to 6GB+. OpenSearch needs 2GB just for itself |
| Webpack build fails with `less` error | The Dockerfile pins `less@4.5.1`. If building outside Docker, run `npm install -g less@4.5.1` first |
| `Pipfile.lock` out of date | Delete it and rebuild: `docker build -t invenioup:latest .` |
| "CSRF token missing" errors | Clear browser cookies or use incognito mode |
| Container exits with code 137 | Out of memory. Increase Docker Desktop memory allocation |
| Init seems stuck | Watch logs: `docker compose logs -f web-ui web-api worker` -- init takes ~60s on first run |
| `network stackcar declared as external, but could not be found` | Run `sc proxy up` first to create the shared Traefik network |

---

## Service URLs (Local Dev)

| Service | URL | Credentials |
|---------|-----|-------------|
| InvenioRDM (UI) | https://invenioup.localhost.direct | Values from `.env` (`INVENIO_ADMIN_*`) |
| InvenioRDM (API) | https://invenioup.localhost.direct/api | same |
| Traefik Dashboard | https://traefik.localhost.direct | -- |
| pgAdmin | http://127.0.0.1:5050 | info@notch8.com / invenioup |
| RabbitMQ | http://127.0.0.1:15672 | guest / guest |
| OpenSearch Dashboards | http://127.0.0.1:5601 | -- |
| MinIO Console | http://127.0.0.1:9001 | `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env` |
