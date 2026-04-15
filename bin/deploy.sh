#!/usr/bin/env bash
# Local / scripted deploy: render ops/<env>-deploy.tmpl.yaml → ops/<env>-deploy.yaml, then helm upgrade.
#
# Usage:
#   export RABBITMQ_PASSWORD=... POSTGRES_PASSWORD=... INVENIO_ADMIN_PASSWORD=...
#   ./bin/deploy.sh <environment> [image_tag]
#
# Example:
#   ./bin/deploy.sh friends "$(git rev-parse --short HEAD)"
#
# Optional env (defaults shown):
#   REPO_LOWER=notch8/invenioup          # image path under ghcr.io (no registry)
#   HELM_RELEASE_NAME=invenioup-<env>   # override release + namespace base
#   KUBE_NAMESPACE=invenioup-<env>
#   CHART_VERSION=0.11.1
#
set -euo pipefail

ENV="${1:?usage: ./bin/deploy.sh <environment> [image_tag]}"
TAG="${2:-${TAG:-latest}}"

export HELM_EXPERIMENTAL_OCI="${HELM_EXPERIMENTAL_OCI:-1}"
export HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-invenioup-${ENV}}"
export KUBE_NAMESPACE="${KUBE_NAMESPACE:-invenioup-${ENV}}"
export HELM_EXTRA_ARGS="--values ops/${ENV}-deploy.yaml"

export TAG="$TAG"
export DEPLOY_TAG="$TAG"
export REPO_LOWER="${REPO_LOWER:-notch8/invenioup}"

export DEPLOY_IMAGE="ghcr.io/${REPO_LOWER}/web"
export WORKER_IMAGE="$DEPLOY_IMAGE"
export INVENIO_ADMIN_EMAIL="${INVENIO_ADMIN_EMAIL}"

TMPL="ops/${ENV}-deploy.tmpl.yaml"
OUT="ops/${ENV}-deploy.yaml"

if [[ ! -f "$TMPL" ]]; then
  echo "error: missing $TMPL" >&2
  exit 1
fi

for v in RABBITMQ_PASSWORD POSTGRES_PASSWORD INVENIO_ADMIN_PASSWORD; do
  if [[ -z "${!v:-}" ]]; then
    echo "error: export $v before running (required by $TMPL)" >&2
    exit 1
  fi
done

envsubst '$RABBITMQ_PASSWORD $POSTGRES_PASSWORD $INVENIO_ADMIN_EMAIL $INVENIO_ADMIN_PASSWORD' < "$TMPL" > "$OUT"

./bin/helm_deploy "$HELM_RELEASE_NAME" "$KUBE_NAMESPACE"
./bin/invenio_alembic_upgrade "$HELM_RELEASE_NAME" "$KUBE_NAMESPACE"
