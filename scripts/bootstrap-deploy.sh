#!/usr/bin/env bash
# ============================================================
# Legacy bootstrap (old helm/values.yaml + inveniordm-demo naming).
# Prefer: ops/<env>-deploy.tmpl.yaml + ./bin/deploy.sh <env> [tag]
# ============================================================
#
# Prerequisites:
#   - kubectl configured for r2-friends cluster
#   - helm 3.x installed
#   - Docker image already pushed to GHCR
#
# Usage:
#   ./scripts/bootstrap-deploy.sh
# ============================================================
set -euo pipefail

NAMESPACE="inveniordm"
RELEASE="inveniordm-demo"
VALUES="helm/values.yaml"

echo "==> Adding helm-invenio repo..."
helm repo add helm-invenio https://inveniosoftware.github.io/helm-invenio/ 2>/dev/null || true
helm repo update

echo "==> Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}" 2>/dev/null || true

echo "==> Deploying ${RELEASE} with init=true..."
helm upgrade --install "${RELEASE}" helm-invenio/invenio \
  -f "${VALUES}" \
  --set invenio.init=true \
  --namespace "${NAMESPACE}" \
  --wait \
  --timeout 15m

echo "==> Waiting for pods to be ready..."
kubectl -n "${NAMESPACE}" wait --for=condition=ready pod -l app.kubernetes.io/name=invenio --timeout=300s

echo ""
echo "============================================================"
echo "  InvenioRDM Demo deployed successfully!"
echo ""
echo "  Next steps:"
echo "    1. Check pod status:  kubectl -n ${NAMESPACE} get pods"
echo "    2. Check logs:        kubectl -n ${NAMESPACE} logs -l app.kubernetes.io/name=invenio -c web"
echo "    3. Set init=false in helm/values.yaml for subsequent deploys"
echo "    4. If you need CLI access, scale the terminal pod:"
echo "       kubectl -n ${NAMESPACE} scale deployment/${RELEASE}-terminal --replicas=1"
echo "       kubectl -n ${NAMESPACE} exec -it deploy/${RELEASE}-terminal -- /bin/bash"
echo ""
echo "  Manual init commands (if init job didn't run):"
echo "    kubectl -n ${NAMESPACE} exec -it deploy/${RELEASE}-terminal -- bash -c '"
echo "      invenio db init create && \\"
echo "      invenio index init && \\"
echo "      invenio files location create default s3://demo-invenioup --default && \\"
echo "      invenio rdm-records fixtures && \\"
echo "      invenio users create admin@notch8.com --password <PASSWORD> --active --confirm"
echo "    '"
echo "============================================================"
