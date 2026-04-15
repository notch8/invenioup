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
| `ops/<env>-deploy.tmpl.yaml` | Committed overrides; only **`$RABBITMQ_PASSWORD`** and **`$POSTGRES_PASSWORD`** are replaced by `envsubst`. S3 uses a separate Kubernetes Secret (see below). |
| `ops/<env>-deploy.yaml` | Generated at deploy time (**gitignored**). Do not commit. |
| `bin/helm_deploy` | Pulls [helm-invenio](https://github.com/inveniosoftware/helm-invenio), runs `helm upgrade --install`. |
| `bin/deploy.sh` | Renders the tmpl → yaml, runs `helm_deploy`, then **`bin/invenio_alembic_upgrade`**. |
| `bin/invenio_alembic_upgrade` | `kubectl exec` into `<release>-web` and runs **`invenio alembic upgrade heads`** (not `invenio db upgrade`). |

### PostgreSQL

The app user must be able to create objects in **`public`**. On PostgreSQL **15+**, grant at least:

`GRANT USAGE, CREATE ON SCHEMA public TO <app_user>;`

`GRANT ALL PRIVILEGES ON DATABASE` alone is **not** enough. If migrations fail with mixed or half-applied schema, prefer a coordinated reset (backup first) rather than patching by hand.

### S3 file storage (Kubernetes)

`invenio.cfg` uses **`invenio_s3`**. Web and worker pods need **`INVENIO_S3_ENDPOINT_URL`**, **`INVENIO_S3_ACCESS_KEY_ID`**, and **`INVENIO_S3_SECRET_ACCESS_KEY`** (see `.env.example` for local names).

Helm values mount an extra Secret named **`{helm-release-name}-s3`** (for example `invenioup-friends-s3` when the release is `invenioup-friends`). **Create or update that Secret in the namespace before `helm upgrade`**, or pods will fail to start when they reference a missing Secret.

1. **AWS: bucket and dedicated IAM user**

   - In **S3**, create a bucket in your chosen region (example: `us-west-2`). Block public access should stay on unless you have a deliberate public-assets design.
   - In **IAM → Users → Create user**: choose a name (for example `invenioup-friends-s3`). Invenio does **not** need console sign-in; attach the policy below, then create an **access key** under **Security credentials**.
   - **Do not** attach `AmazonS3FullAccess` for production. Instead, attach an **inline policy** (or a dedicated customer-managed policy) scoped to **one bucket** (and optional prefix). Example policy — replace `YOUR_BUCKET_NAME` and, if you use a prefix, narrow `Resource` ARNs with `YOUR_BUCKET_NAME/your-prefix/*`:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "ListBucket",
         "Effect": "Allow",
         "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
         "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME"
       },
       {
         "Sid": "ObjectRW",
         "Effect": "Allow",
         "Action": [
           "s3:GetObject",
           "s3:PutObject",
           "s3:DeleteObject",
           "s3:AbortMultipartUpload",
           "s3:ListMultipartUploadParts"
         ],
         "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
       }
     ]
   }
   ```

   - **IAM → Users → your user → Security credentials → Create access key** → use case **Application running outside AWS** (or **Local code**). Save the **Access key ID** and **Secret access key** once; the secret is shown only at creation time. These map directly to **`INVENIO_S3_ACCESS_KEY_ID`** and **`INVENIO_S3_SECRET_ACCESS_KEY`**.
   - Set **`INVENIO_S3_ENDPOINT_URL`** to the regional endpoint for S3 in that region, typically `https://s3.<region>.amazonaws.com` (for example `https://s3.us-west-2.amazonaws.com`). Use the same region where the bucket lives.

   **AWS CLI** (optional): after saving the JSON policy above as `invenioup-s3-policy.json` (with your real bucket name), you can run:

   ```bash
   USER_NAME=invenioup-friends-s3
   aws iam create-user --user-name "$USER_NAME"
   aws iam put-user-policy \
     --user-name "$USER_NAME" \
     --policy-name invenioup-friends-s3-bucket \
     --policy-document file://invenioup-s3-policy.json
   aws iam create-access-key --user-name "$USER_NAME"
   ```

   The last command prints **`AccessKeyId`** and **`SecretAccessKey`**; use those in the Kubernetes Secret. Rotate keys by creating a new access key, updating the Secret, restarting workloads, then deleting the old key.

2. **Kubernetes Secret** (replace release, namespace, endpoint, and paste the IAM access key id and secret from the step above):

   ```bash
   RELEASE=invenioup-friends
   NS=invenioup-friends

   kubectl create secret generic "${RELEASE}-s3" \
     --namespace="${NS}" \
     --from-literal=INVENIO_S3_ENDPOINT_URL='https://s3.us-west-2.amazonaws.com' \
     --from-literal=INVENIO_S3_ACCESS_KEY_ID='YOUR_ACCESS_KEY' \
     --from-literal=INVENIO_S3_SECRET_ACCESS_KEY='YOUR_SECRET_KEY'
   ```

   To update an existing Secret, delete and recreate it, or use `kubectl create secret generic ... --dry-run=client -o yaml | kubectl apply -f -`.

   For **MinIO** inside the cluster, set `INVENIO_S3_ENDPOINT_URL` to the service URL (for example `http://minio.my-namespace.svc.cluster.local:9000/`) and use that deployment’s root/user credentials.

3. Deploy with Helm as usual. After the first boot, ensure a default **files location** exists for that bucket (the chart init job may do this; if `invenio files location list` is empty, run inside the **web** pod):

   ```bash
   invenio files location create --default default-location "s3://YOUR_BUCKET_NAME/"
   ```

### CI/CD

- **Build** (`.github/workflows/build-test-lint.yml`): runs on **push** / PR to `main` (and manual dispatch); builds and pushes images (e.g. to GHCR).
- **Deploy** (`.github/workflows/deploy.yml`): **workflow_dispatch** — kubeconfig from secrets, **`envsubst`** on `ops/<environment>-deploy.tmpl.yaml`, **`bin/helm_deploy`**, **`bin/invenio_alembic_upgrade`**. Secrets include **`POSTGRES_PASSWORD`**, **`RABBITMQ_PASSWORD`**, and **`INVENIO_ADMIN_PASSWORD`**; **`INVENIO_ADMIN_EMAIL`** defaults to `admin@notch8.com` or use the repo **Actions variable** of the same name. Those feed **`invenio.default_users`** in the friends template. Optional checkbox **Run RDM bootstrap** runs **`bin/k8s_bootstrap_rdm`** once on a new cluster (see below).

### Scripted deploy (local CLI)

```bash
export RABBITMQ_PASSWORD=... POSTGRES_PASSWORD=... INVENIO_ADMIN_PASSWORD=...
export INVENIO_ADMIN_EMAIL=you@example.com   # optional; default admin@notch8.com in bin/deploy.sh
./bin/deploy.sh friends "$(git rev-parse --short HEAD)"
```

Optional env: `HELM_RELEASE_NAME`, `KUBE_NAMESPACE`, `REPO_LOWER`, `CHART_VERSION`, `DEPLOY_IMAGE` / `DEPLOY_TAG` (see `bin/helm_deploy` and `bin/deploy.sh`).

### Helm `invenio.init` and RDM bootstrap (Kubernetes vs Docker)

Docker **`INVENIO_AUTO_INIT=true`** runs **`scripts/invenio-first-run-init.sh`** (via the web entrypoint): DB, files location, roles, indexes, **RDM custom-fields**, **fixtures**, admin user, optional demo.

The **helm-invenio** post-install job is smaller: DB, index, files location, `admin` role, and **`invenio.default_users`** from values — it does **not** run **`invenio rdm-records custom-fields init`**, **`communities custom-fields init`**, **`rdm-records fixtures`**, extra administration roles, **`roles add … admin`** for the chart-created user, or demo.

After the **first** successful install (with **`invenio.init: true`**), run the supplemental script **once** (image must include `/usr/local/bin/invenio-k8s-rdm-bootstrap`):

```bash
export INVENIO_ADMIN_EMAIL=admin@notch8.com   # optional; must match default_users in values
./bin/k8s_bootstrap_rdm <release-name> <namespace>
```

Or enable **Run RDM bootstrap** on the Deploy workflow for that release. On later upgrades, leave **`invenio.init: false`** (per chart docs) and do **not** re-run bootstrap unless you know you need it.

After **one** successful full bootstrap, set **`invenio.init: false`** in `ops/<env>-deploy.tmpl.yaml` and **`helm upgrade`** again so install hooks do not re-run unnecessarily.

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
| `docker/entrypoint.sh` | Waits for deps, then first-run init when `INVENIO_AUTO_INIT=true` |
| `scripts/invenio-first-run-init.sh` | Full first-run DB/RDM setup (used by Docker entrypoint) |
| `scripts/invenio-k8s-rdm-bootstrap.sh` | RDM layers after helm install-init (run via `bin/k8s_bootstrap_rdm`) |
| `bin/k8s_bootstrap_rdm` | `kubectl exec` wrapper for `invenio-k8s-rdm-bootstrap` |
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
