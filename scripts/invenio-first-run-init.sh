#!/bin/bash
# Full first-time instance setup (same steps as Docker INVENIO_AUTO_INIT=true).
# Idempotent gate: skips if alembic_version table already exists.
set -euo pipefail

ADMIN_EMAIL="${INVENIO_ADMIN_EMAIL}"
ADMIN_PASSWORD="${INVENIO_ADMIN_PASSWORD}"

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

if [ "$DB_INITIALIZED" = "yes" ]; then
  echo "invenio-first-run-init: database already initialized, skipping"
  exit 0
fi

echo "invenio-first-run-init: first run -- creating DB, indexes, RDM data..."

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

echo "invenio-first-run-init: complete"
