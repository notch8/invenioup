# InvenioRDM Demo Instance

Notch8-hosted InvenioRDM v13.1 demo instance for business development.

## Quick Start (Local Development)

### Prerequisites

- Docker & Docker Compose v2
- [Stack Car](https://github.com/notch8/stack_car) proxy running (`sc proxy up`)
- Docker Desktop memory: allocate at least **6 GB** (Preferences > Resources)

### First-time setup

```bash
cp .env.example .env     # required: Docker Compose loads .env into app containers
sc proxy up              # start Traefik (if not already running)
docker compose up --build -d
```

That's it. On first run the `web-ui` container automatically:
- Waits for PostgreSQL, OpenSearch, Redis, and RabbitMQ
- Creates the database and search indexes
- Loads vocabularies and fixtures
- Creates an admin user
- Loads demo records

Open **https://invenioup.localhost.direct** and log in with the admin email and
password from your `.env` (`INVENIO_ADMIN_EMAIL` / `INVENIO_ADMIN_PASSWORD`,
matching `.env.example` defaults unless you changed them).

Stack Car's Traefik proxy handles TLS termination with the `localhost.direct`
wildcard cert. The Traefik dashboard is at **https://traefik.localhost.direct**.

### Daily workflow

```bash
docker compose up -d          # Start everything
docker compose down           # Stop (data persists)
docker compose down -v        # Nuclear reset (wipes all data)
docker compose logs -f web-ui web-api worker   # Tail app logs
docker compose exec web-ui bash                # Shell into the app
```

To build images without bringing the stack up (optional):

```bash
docker build -t invenioup:latest .
docker build -t invenioup-frontend:latest ./docker/nginx/
```

### Testing

```bash
# Smoke tests (curl-based health checks)
./scripts/smoke-test.sh

# Playwright e2e tests (requires: cd tests/e2e && npm install && npx playwright install chromium)
cd tests/e2e && npx playwright test
```

## Deployment (r2-friends K8s Cluster)

### First-time setup

1. Create K8s secrets (see `helm/secrets/README.md`)
2. Run the bootstrap script:
   ```bash
   ./scripts/bootstrap-deploy.sh
   ```
3. After successful first deploy, set `invenio.init: false` in `helm/values.yaml`

### Subsequent deploys

Push to `main` triggers the GitHub Actions pipeline which builds the Docker
image and runs `helm upgrade`.

### Manual deploy

```bash
helm repo add helm-invenio https://inveniosoftware.github.io/helm-invenio/
helm upgrade --install inveniordm-demo helm-invenio/invenio \
  -f helm/values.yaml \
  --namespace inveniordm
```

## Configuration

| File | Purpose |
|------|---------|
| `invenio.cfg` | Main InvenioRDM configuration |
| `Pipfile` | Python dependencies |
| `docker-compose.yml` | Docker Compose services |
| `docker/entrypoint.sh` | Auto-init entrypoint (first-run setup) |
| `helm/values.yaml` | Helm chart overrides for K8s |
| `assets/less/theme.less` | Custom CSS/LESS theme |
| `templates/` | Jinja2 template overrides |
| `site/` | Custom Python code package |
| `app_data/` | Vocabularies and fixtures |

## Architecture

- **Edge Router**: Traefik via Stack Car (TLS termination, HTTP→HTTPS redirect)
- **Web**: InvenioRDM Flask app served by uWSGI behind Nginx (uwsgi proxy)
- **Worker**: Celery worker for async tasks (DOI registration, indexing, etc.)
- **Beat**: Celery beat scheduler for periodic jobs
- **Database**: PostgreSQL (existing cluster DB)
- **Search**: OpenSearch 2.x
- **Cache/Sessions**: Redis
- **Message Queue**: RabbitMQ
- **File Storage**: AWS S3

## Key references

- [InvenioRDM Docs](https://inveniordm.docs.cern.ch/)
- [helm-invenio chart](https://github.com/inveniosoftware/helm-invenio)
- [InvenioRDM Discord](https://discord.gg/8qatqBC)
