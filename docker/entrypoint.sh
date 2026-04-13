#!/bin/bash
set -e

ADMIN_EMAIL="${INVENIO_ADMIN_EMAIL:-admin@notch8.com}"
ADMIN_PASSWORD="${INVENIO_ADMIN_PASSWORD:-changeme123}"

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

# ── First-run auto-init (web-ui only) ──────────────────────────
if [ "$INVENIO_AUTO_INIT" = "true" ]; then
  DB_INITIALIZED=$(python -c "
import psycopg2, os
dsn = os.environ.get('INVENIO_SQLALCHEMY_DATABASE_URI','').replace('+psycopg2','')
try:
    conn = psycopg2.connect(dsn)
    cur = conn.cursor()
    cur.execute(\"SELECT 1 FROM information_schema.tables WHERE table_name='alembic_version'\")
    print('yes' if cur.fetchone() else 'no')
    conn.close()
except Exception:
    print('no')
" 2>/dev/null)

  if [ "$DB_INITIALIZED" != "yes" ]; then
    echo "entrypoint: first run detected -- initializing..."

    invenio db init create
    invenio files location create --default default-location "${INVENIO_INSTANCE_PATH}/data"

    invenio roles create admin
    invenio access allow superuser-access role admin
    invenio roles create administration
    invenio access allow administration-access role administration
    invenio roles create administration-moderation
    invenio access allow administration-moderation role administration-moderation

    invenio index init --force
    invenio rdm-records custom-fields init
    invenio communities custom-fields init

    invenio rdm-records fixtures

    invenio users create "$ADMIN_EMAIL" --password "$ADMIN_PASSWORD" --active --confirm
    invenio roles add "$ADMIN_EMAIL" admin

    invenio rdm-records demo || true

    echo "entrypoint: initialization complete"
  else
    echo "entrypoint: database already initialized, skipping setup"
  fi
fi

# ── Hand off to the container command ──────────────────────────
exec bash -c "$@"
