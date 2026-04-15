#!/bin/bash
# Run after helm-invenio post-install (or any DB that already has alembic tables).
# The chart init job creates the DB and a user from default_users but does not run
# RDM custom-fields, fixtures, administration roles, admin role assignment, or demo.
# Safe to run more than once where commands are idempotent; demo/fixtures may no-op or warn.
set -euo pipefail

ADMIN_EMAIL="${INVENIO_ADMIN_EMAIL}"

echo "invenio-k8s-rdm-bootstrap: RDM layers and roles..."

invenio rdm-records custom-fields init
invenio communities custom-fields init
invenio rdm-records fixtures || true

invenio roles create administration 2>/dev/null || true
invenio access allow administration-access role administration 2>/dev/null || true
invenio roles create administration-moderation 2>/dev/null || true
invenio access allow administration-moderation role administration-moderation 2>/dev/null || true

invenio roles add "$ADMIN_EMAIL" admin 2>/dev/null || true

invenio rdm-records demo || true

echo "invenio-k8s-rdm-bootstrap: complete"
