#!/usr/bin/env bash
#
# Smoke tests for InvenioRDM deployment.
# Validates that all critical services are wired up and responding.
#
# Usage:
#   ./scripts/smoke-test.sh                   # defaults to https://invenioup.localhost.direct
#   ./scripts/smoke-test.sh https://staging.example.com
#
set -euo pipefail

BASE_URL="${1:-https://invenioup.localhost.direct}"
PASS=0
FAIL=0
ERRORS=""

check() {
  local name="$1"
  local url="$2"
  local expect_status="${3:-200}"
  local method="${4:-GET}"

  local status
  status=$(curl -sS -k --max-time 15 -o /dev/null -w '%{http_code}' -X "$method" "$url" 2>/dev/null) || true

  if [ "$status" = "$expect_status" ]; then
    echo "  PASS  $name ($status)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (got $status, expected $expect_status)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  - $name: got $status, expected $expect_status"
  fi
}

check_contains() {
  local name="$1"
  local url="$2"
  local needle="$3"

  local body
  body=$(curl -sS -k --max-time 15 "$url" 2>/dev/null) || true

  if echo "$body" | grep -qi "$needle"; then
    echo "  PASS  $name (contains '$needle')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (missing '$needle')"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  - $name: response missing '$needle'"
  fi
}

echo ""
echo "=== InvenioRDM Smoke Tests ==="
echo "    Target: $BASE_URL"
echo ""

echo "--- Liveness ---"
check "Health ping"           "$BASE_URL/ping"
check "Frontpage loads"       "$BASE_URL/"

echo ""
echo "--- API layer (DB + OpenSearch) ---"
check "Records API"           "$BASE_URL/api/records"
check "Communities API"       "$BASE_URL/api/communities"

echo ""
echo "--- Fixtures & vocabularies ---"
check "Resource types vocab"  "$BASE_URL/api/vocabularies/resourcetypes"

echo ""
echo "--- Content checks ---"
check_contains "Frontpage branding" "$BASE_URL/" "InvenioRDM"

echo ""
echo "================================"
echo "  Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo -e "  Failures:$ERRORS"
  echo "================================"
  exit 1
fi
echo "================================"
echo ""
