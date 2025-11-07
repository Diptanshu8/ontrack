#!/bin/bash

# Start Test Server Script
# Sets up test database and starts Rails test server on port 3001

set -euo pipefail  # Exit on error, unset vars are errors, and pipelines fail on first error

# Initialize rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - bash)"

PROJECT_ROOT="/Users/djamgade/personal/ontrack/ontrack"

# Ensure Rails runs in test environment
export RAILS_ENV=test

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${BLUE}▶${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

echo ""
echo "======================================"
echo "🚀 Starting Test Server"
echo "======================================"
echo ""

# Check if server is already running
if lsof -i :3001 -t >/dev/null 2>&1 ; then
    warn "Server already running on port 3001"
    PID=$(lsof -i :3001 -t)
    echo "PID: $PID"
    echo ""
    # In automated testing, always kill and restart
    kill -9 $PID 2>/dev/null || true
    sleep 2
    success "Killed existing server"
fi

# Setup test database
log "Setting up test database..."
cd "$PROJECT_ROOT"

# If a seed dump is provided, always restore from it for a clean slate
SEED_DUMP_PATH="${TEST_DB_SEED_DUMP:-}"
if [ -n "$SEED_DUMP_PATH" ] && [ -f "$SEED_DUMP_PATH" ]; then
    warn "Using seed dump to recreate test DB: $SEED_DUMP_PATH"
    dropdb --if-exists ontrack_test || true
    createdb ontrack_test
    psql ontrack_test < "$SEED_DUMP_PATH" > /dev/null 2>&1
    success "Restored 'ontrack_test' from seed dump"
else
    SOURCE_DB="${TEST_DB_SOURCE_DB:-ontrack_development}"
    info "TEST_DB_SEED_DUMP not provided - cloning ${SOURCE_DB} -> ontrack_test"
    
    # Always drop and recreate test DB for a clean slate
    dropdb --if-exists ontrack_test || true
    createdb ontrack_test
    pg_dump --no-owner --no-privileges "$SOURCE_DB" | psql ontrack_test > /dev/null 2>&1
    success "Recreated test database from '$SOURCE_DB'"
fi

# Start Rails test server
log "Starting test server on port 3001..."
RAILS_ENV=test bundle exec rails server -p 3001 -b 0.0.0.0 > /tmp/test_server.log 2>&1 &
SERVER_PID=$!
echo $SERVER_PID > /tmp/test_server.pid
info "Test server started (PID: $SERVER_PID)"

# Wait for the server to be ready
for i in {1..30}; do
    if curl -sSf http://localhost:3001 > /dev/null 2>&1; then
        success "Test server is ready on http://localhost:3001"
        break
    fi
    sleep 1
done

if ! curl -sSf http://localhost:3001 > /dev/null 2>&1; then
    error "Test server failed to start within 30s"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Validate server health
log "Validating server health..."

# Test login API
LOGIN_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d '{"username":"Diptanshu", "password":"finance"}' http://localhost:3001/api/v1/auth/login)
LOGIN_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token' 2>/dev/null)
if [ -n "$LOGIN_TOKEN" ] && [ "$LOGIN_TOKEN" != "null" ]; then
    success "Login API working (token received)"
else
    error "Login API failed"
    exit 1
fi

# Test categories API
CATEGORIES_RESPONSE=$(curl -s -H "Authorization: Bearer $LOGIN_TOKEN" http://localhost:3001/api/v1/categories)
if echo "$CATEGORIES_RESPONSE" | jq -e '.[] | has("id")' > /dev/null 2>&1; then
    success "Categories API working"
else
    error "Categories API failed"
    exit 1
fi

# Test expenses API
EXPENSES_RESPONSE=$(curl -s -H "Authorization: Bearer $LOGIN_TOKEN" http://localhost:3001/api/v1/expenses)
if echo "$EXPENSES_RESPONSE" | jq -e '.[] | has("id")' > /dev/null 2>&1; then
    success "Expenses API working"
else
    error "Expenses API failed"
    exit 1
fi

# Reports: available years → year & current month
AVAILABLE_YEARS=$(curl -fsS "http://localhost:3001/api/v1/reports/available_years" -H "Authorization: Bearer $LOGIN_TOKEN")
YEAR=$(echo "$AVAILABLE_YEARS" | jq -r '.years[0] // 2025')
MONTH_LABEL=$(date "+%B %Y")

# Year report
if curl -fsS "http://localhost:3001/api/v1/reports/year?year=$YEAR" -H "Authorization: Bearer $LOGIN_TOKEN" > /dev/null; then
    success "Year report ($YEAR) OK"
else
    error "Year report failed"
    exit 1
fi

# Month report (URL-encoded month label)
ENC_MONTH_LABEL=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$MONTH_LABEL")
if curl -fsS "http://localhost:3001/api/v1/reports/month?month=$ENC_MONTH_LABEL" -H "Authorization: Bearer $LOGIN_TOKEN" > /dev/null; then
    success "Month report ($MONTH_LABEL) OK"
else
    error "Month report failed"
    exit 1
fi

success "Server health check passed"
echo ""
echo "======================================"
success "Test server ready!"
echo "======================================"
echo ""
info "Server URL: http://localhost:3001"
info "PID: $SERVER_PID (saved to /tmp/test_server.pid)"
info "Logs: /tmp/test_server.log"
echo ""
info "To stop: bash cleanup_test_server.sh"
echo ""

