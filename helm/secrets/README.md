# Kubernetes Secrets for InvenioRDM Demo

These secret manifests are **templates only**. Replace placeholder values
before applying, or better yet, manage secrets via GitHub Actions secrets
and apply them in CI.

**Never commit real credentials to version control.**

## Apply secrets manually (one-time setup)

```bash
# Create namespace first
kubectl create namespace inveniordm

# Apply each secret (after filling in real values)
kubectl apply -f helm/secrets/db-credentials.yaml
kubectl apply -f helm/secrets/s3-credentials.yaml
kubectl apply -f helm/secrets/app-secrets.yaml
kubectl apply -f helm/secrets/ghcr-credentials.yaml
```

## Or create secrets imperatively

```bash
kubectl -n inveniordm create secret generic inveniordm-db-credentials \
  --from-literal=password='YOUR_DB_PASSWORD'

kubectl -n inveniordm create secret generic inveniordm-s3-credentials \
  --from-literal=INVENIO_S3_ACCESS_KEY_ID='YOUR_ACCESS_KEY' \
  --from-literal=INVENIO_S3_SECRET_ACCESS_KEY='YOUR_SECRET_KEY' \
  --from-literal=INVENIO_S3_ENDPOINT_URL='' \
  --from-literal=INVENIO_S3_REGION_NAME='us-east-1'

kubectl -n inveniordm create secret generic inveniordm-app-secrets \
  --from-literal=INVENIO_SECRET_KEY="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"

kubectl -n inveniordm create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT
```
