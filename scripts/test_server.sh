#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/djamgade/personal/ontrack/ontrack"
cd "$ROOT_DIR"

echo "[test-server] Bootstrapping test environment..."

# Ensure rbenv and bundler are available
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi

export RAILS_ENV=test

echo "[test-server] Stopping any existing server on :3001"
lsof -ti:3001 | xargs kill -9 2>/dev/null || true

echo "[test-server] Recreating test database from development..."
dropdb --if-exists ontrack_test || true
createdb ontrack_test

# Full dump (schema + data) from development into test
pg_dump --no-owner --no-privileges ontrack_development | psql ontrack_test

echo "[test-server] Starting Rails test server on http://localhost:3001 ..."
mkdir -p log tmp
nohup bash -lc 'eval "$(rbenv init -)"; RAILS_ENV=test bundle exec rails s -b 0.0.0.0 -p 3001' \
  >> log/test_server.log 2>&1 &
SERVER_PID=$!
echo $SERVER_PID > tmp/test_server.pid

echo "[test-server] Waiting for server to be ready..."
for i in {1..30}; do
  if curl -sSf http://localhost:3001 > /dev/null; then
    break
  fi
  sleep 1
done

echo "[test-server] Running health checks..."

# Login and get token
TOKEN=$(curl -s -X POST http://localhost:3001/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"Diptanshu","password":"finance"}' | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['token'])")

if [[ -z "${TOKEN:-}" ]]; then
  echo "[test-server] ❌ Login failed - token missing"
  kill "$SERVER_PID" || true
  exit 1
fi

echo "[test-server] ✅ Login OK"

# Categories
curl -fsS "http://localhost:3001/api/v1/categories" -H "Authorization: Bearer $TOKEN" > /dev/null
echo "[test-server] ✅ Categories OK"

# Reports: available years → year & current month
YEAR=$(curl -fsS "http://localhost:3001/api/v1/reports/available_years" -H "Authorization: Bearer $TOKEN" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print((d.get("years") or [2025])[0])')

MONTH_LABEL=$(date "+%B %Y")

curl -fsS "http://localhost:3001/api/v1/reports/year?year=$YEAR" -H "Authorization: Bearer $TOKEN" > /dev/null
echo "[test-server] ✅ Year report ($YEAR) OK"

curl -fsS "http://localhost:3001/api/v1/reports/month?month=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$MONTH_LABEL")" \
  -H "Authorization: Bearer $TOKEN" > /dev/null
echo "[test-server] ✅ Month report ($MONTH_LABEL) OK"

echo "[test-server] ✅ All health checks passed. Server PID: $SERVER_PID"
echo "[test-server] Logs: $ROOT_DIR/log/test_server.log"
exit 0


