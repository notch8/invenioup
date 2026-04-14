# InvenioRDM Demo Instance

Notch8-hosted **InvenioRDM v13.x** demo instance for business development (see `Pipfile` for the pinned line).

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

On first run the `web-ui` service (`INVENIO_AUTO_INIT=true` in `docker-compose.yml`) will wait for dependencies, initialize the database and indexes, load fixtures, and create an admin user.

### Login (local)

Use **`INVENIO_ADMIN_EMAIL`** and **`INVENIO_ADMIN_PASSWORD`** from your `.env`. Defaults match `.env.example` (e.g. `admin@notch8.com` / `changeme123`). After `docker compose down -v`, the next `up` is a fresh init with the same defaults unless you changed `.env`.

Open **https://invenioup.localhost.direct**. Stack Car’s Traefik terminates TLS (`localhost.direct`); dashboard at **https://traefik.localhost.direct**.

### Daily workflow

```bash
docker compose up -d          # Start everything
docker compose down           # Stop (data persists)
docker compose down -v        # Nuclear reset (wipes all data)
docker compose logs -f web-ui web-api worker   # Tail app logs
docker compose exec web-ui bash                # Shell into the app
```

Optional local image builds:

```bash
docker build -t invenioup:latest .
docker build -t invenioup-frontend:latest ./docker/nginx/
```

### Testing

```bash
./scripts/smoke-test.sh
cd tests/e2e && npm install && npx playwright install chromium && npx playwright test
```

## Deployment (Kubernetes)

Helm values live under **`ops/`**, not a root `helm/` tree.

| Item | Role |
|------|------|
| `ops/<env>-deploy.tmpl.yaml` | Committed overrides; only **`$RABBITMQ_PASSWORD`** and **`$POSTGRES_PASSWORD`** are replaced by `envsubst`. |
| `ops/<env>-deploy.yaml` | Generated at deploy time (**gitignored**). Do not commit. |
| `bin/helm_deploy` | Pulls [helm-invenio](https://github.com/inveniosoftware/helm-invenio), runs `helm upgrade --install`. |
| `bin/deploy.sh` | Renders the tmpl → yaml, runs `helm_deploy`, then **`bin/invenio_alembic_upgrade`**. |
| `bin/invenio_alembic_upgrade` | `kubectl exec` into `<release>-web` and runs **`invenio alembic upgrade heads`** (not `invenio db upgrade`). |

### PostgreSQL

The app user must be able to create objects in **`public`**. On PostgreSQL **15+**, grant at least:

`GRANT USAGE, CREATE ON SCHEMA public TO <app_user>;`

`GRANT ALL PRIVILEGES ON DATABASE` alone is **not** enough. If migrations fail with mixed or half-applied schema, prefer a coordinated reset (backup first) rather than patching by hand.

### CI/CD

- **Build** (`.github/workflows/build-test-lint.yml`): runs on **push** / PR to `main` (and manual dispatch); builds and pushes images (e.g. to GHCR).
- **Deploy** (`.github/workflows/deploy.yml`): **workflow_dispatch** only — kubeconfig from secrets, renders `ops/<environment>-deploy.tmpl.yaml`, **`bin/helm_deploy`**, then **`bin/invenio_alembic_upgrade`**. Requires matching **secrets** and **environment** inputs (see the workflow and your org’s `setup-env` action, if used).

### Scripted deploy (local CLI)

```bash
export RABBITMQ_PASSWORD=... POSTGRES_PASSWORD=...
./bin/deploy.sh friends "$(git rev-parse --short HEAD)"
```

Optional env: `HELM_RELEASE_NAME`, `KUBE_NAMESPACE`, `REPO_LOWER`, `CHART_VERSION`, `DEPLOY_IMAGE` / `DEPLOY_TAG` (see `bin/helm_deploy` and `bin/deploy.sh`).

### Helm `invenio.init`

In `ops/<env>-deploy.tmpl.yaml`, **`invenio.init: true`** enables the chart’s first-install job. After **one** successful bootstrap, set **`invenio.init: false`** and upgrade again so hooks do not re-run unnecessarily.

### Admin user and roles (cluster)

If no admin exists (e.g. new DB, or roles never created), run inside the **web** container:

```bash
# Replace release and namespace (e.g. invenioup-friends / invenioup-friends)
kubectl exec -n <namespace> deploy/<release>-web -c web -- invenio roles create admin
kubectl exec -n <namespace> deploy/<release>-web -c web -- invenio access allow superuser-access role admin
kubectl exec -n <namespace> deploy/<release>-web -c web -- \
  invenio users create you@example.com --password '<secure>' --active --confirm
kubectl exec -n <namespace> deploy/<release>-web -c web -- \
  invenio roles add you@example.com admin
```

Skip **`roles create admin`** if the role already exists.

### Legacy script

`scripts/bootstrap-deploy.sh` targets an older layout (`helm/values.yaml`, `inveniordm-demo`). Prefer **`bin/deploy.sh`** and **`ops/`** above.

## Configuration

| File | Purpose |
|------|---------|
| `invenio.cfg` | Main InvenioRDM configuration |
| `Pipfile` | Python dependencies |
| `docker-compose.yml` | Local stack services |
| `docker/entrypoint.sh` | First-run init when `INVENIO_AUTO_INIT=true` |
| `ops/*-deploy.tmpl.yaml` | Kubernetes Helm value overrides (per environment) |
| `assets/less/theme.less` | Custom CSS/LESS theme |
| `templates/` | Jinja2 template overrides |
| `site/` | Custom Python package |
| `app_data/` | Vocabularies and fixtures |

## Architecture

- **Local edge**: Traefik via Stack Car (TLS, redirect)
- **Web**: InvenioRDM (uWSGI) behind Nginx
- **Worker / Beat**: Celery
- **Kubernetes**: [helm-invenio](https://github.com/inveniosoftware/helm-invenio) bundles OpenSearch, Redis, RabbitMQ, etc.; **PostgreSQL** is typically external (see `ops/` templates)
- **Search**: OpenSearch 2.x
- **File storage**: S3-compatible (configure per environment)

## Key references

- [InvenioRDM Docs](https://inveniordm.docs.cern.ch/)
- [helm-invenio chart](https://github.com/inveniosoftware/helm-invenio)
- [InvenioRDM Discord](https://discord.gg/8qatqBC)

More local detail: **`docs/local-setup.md`**.
