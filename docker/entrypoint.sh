#!/bin/bash
set -e

ADMIN_EMAIL="${INVENIO_ADMIN_EMAIL}"
ADMIN_PASSWORD="${INVENIO_ADMIN_PASSWORD}"

# ── Wait for infrastructure services ────────────────────────────
wait_for_service() {
  local name="$1" cmd="$2"
  until eval "$cmd" >/dev/null 2>&1; do
    echo "entrypoint: waiting for $name..."
    sleep 3
  done
  echo "entrypoint: $name is ready"
}

wait_for_service "PostgreSQL" "python -c \"
import psycopg2, os
dsn = os.environ.get('INVENIO_SQLALCHEMY_DATABASE_URI','').replace('+psycopg2','')
psycopg2.connect(dsn).close()
\""

wait_for_service "OpenSearch" "curl -sf http://search:9200"
wait_for_service "Redis"      "python -c \"import redis; redis.Redis(host='cache').ping()\""
wait_for_service "RabbitMQ"   "python -c \"import socket; s=socket.create_connection(('mq',5672),2); s.close()\""

# ── First-run auto-init (web only; same logic as scripts/invenio-first-run-init.sh) ──
if [ "$INVENIO_AUTO_INIT" = "true" ]; then
  export INVENIO_ADMIN_EMAIL="$ADMIN_EMAIL"
  export INVENIO_ADMIN_PASSWORD="$ADMIN_PASSWORD"
  /usr/local/bin/invenio-first-run-init
fi

# ── Hand off to the container command ──────────────────────────
exec bash -c "$@"
