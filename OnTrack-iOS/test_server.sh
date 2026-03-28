#!/bin/bash

# Unified Test Server Manager
# Supports start, stop, restart, and status commands

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/Users/djamgade/personal/ontrack/ontrack"
IOS_ROOT="/Users/djamgade/personal/ontrack/ontrack/OnTrack-iOS/OnTrack"
PID_FILE="/tmp/test_server.pid"
SERVER_LOG="/tmp/test_server.log"
DEFAULT_LOG_GLOB="/tmp/ontrack_*"

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

usage() {
    cat <<EOF

======================================
🛠️  OnTrack Test Server Manager
======================================

Usage: $(basename "$0") <command> [options]

Commands:
  start            Bootstrap test database and start Rails server on port 3001
  stop             Stop the Rails test server (default: cleans logs and shuts simulators)
  restart          Stop and start the server
  status           Show server and simulator status
  help             Show this help message

Global Options:
  --no-cleanup     Skip log cleanup (applies to stop/restart)

Environment Overrides (start command):
  TEST_DB_SEED_DUMP   Path to a SQL dump used to seed the test DB
  TEST_DB_SOURCE_DB   Name of source DB to clone into test DB (default: ontrack_development)

Examples:
  $(basename "$0") start
  $(basename "$0") stop
  $(basename "$0") stop --no-cleanup
  $(basename "$0") restart
  TEST_DB_SOURCE_DB=ontrack_staging $(basename "$0") start

EOF
}

ensure_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' not found"
        exit 1
    fi
}

ensure_prerequisites() {
    ensure_command curl
    ensure_command jq
    ensure_command psql
    ensure_command dropdb
    ensure_command createdb
    ensure_command pg_dump
    ensure_command bundle
    ensure_command rails
}

is_server_running() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid="$(cat "$PID_FILE")"
        if kill -0 "$pid" >/dev/null 2>&1; then
            echo "$pid"
            return 0
        fi
    fi

    if lsof -i :3001 -t >/dev/null 2>&1; then
        lsof -i :3001 -t | head -1
        return 0
    fi

    return 1
}

clean_logs() {
    log "Cleaning up logs..."
    rm -f "$SERVER_LOG" 2>/dev/null || true
    rm -f /tmp/ontrack_full_test_*.log 2>/dev/null || true
    rm -f /tmp/ontrack_tests_*.log 2>/dev/null || true
    rm -f /tmp/single_test_*.log 2>/dev/null || true
    rm -f /tmp/ontrack_isolated_tests.log 2>/dev/null || true
    success "Logs cleaned"
}

shutdown_simulators() {
    log "Shutting down simulators..."
    xcrun simctl shutdown all 2>/dev/null || true
    success "Simulators shut down"
}

start_server() {
    ensure_prerequisites

    echo ""
    echo "======================================"
    echo "🚀 Starting Test Server"
    echo "======================================"
    echo ""

    if pid="$(is_server_running)"; then
        warn "Server already running on port 3001 (PID: $pid)"
        warn "Restarting existing server instance..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 2
    fi

    log "Initializing rbenv..."
    export PATH="$HOME/.rbenv/bin:$PATH"
    if command -v rbenv >/dev/null 2>&1; then
        eval "$(rbenv init - bash)"
        success "rbenv initialized"
    else
        warn "rbenv not found – proceeding without it"
    fi

    export RAILS_ENV=test
    export NODE_OPTIONS=--openssl-legacy-provider

    log "Setting up test database..."
    cd "$PROJECT_ROOT"

    local seed_dump="${TEST_DB_SEED_DUMP:-}"
    local source_db="${TEST_DB_SOURCE_DB:-ontrack_development}"
    local remote_host="${TEST_DB_REMOTE_HOST:-djpi}"
    local remote_db="${TEST_DB_REMOTE_DB:-ontrack_development}"

    if [ -n "$seed_dump" ] && [ -f "$seed_dump" ]; then
        warn "Using seed dump to recreate test DB: $seed_dump"
        dropdb --if-exists ontrack_test || true
        createdb ontrack_test
        psql ontrack_test < "$seed_dump" > /dev/null 2>&1
        success "Restored 'ontrack_test' from seed dump"
    elif psql -lqt | cut -d\| -f1 | grep -qw "$source_db"; then
        info "Cloning local ${source_db} → ontrack_test"
        dropdb --if-exists ontrack_test || true
        createdb ontrack_test
        pg_dump --no-owner --no-privileges "$source_db" | psql ontrack_test > /dev/null 2>&1
        success "Recreated test database from local '$source_db'"
    else
        warn "Local DB '$source_db' not found — cloning from ${remote_host}:${remote_db}..."
        dropdb --if-exists ontrack_test || true
        createdb ontrack_test
        ssh "$remote_host" "sudo -u postgres pg_dump --no-owner --no-privileges -Fp ${remote_db}" \
            | psql ontrack_test > /dev/null 2>&1
        success "Cloned production DB from ${remote_host}:${remote_db} → ontrack_test"
    fi

    log "Starting test server on port 3001..."
    bundle exec rails server -p 3001 -b 0.0.0.0 > "$SERVER_LOG" 2>&1 &
    local server_pid=$!
    echo "$server_pid" > "$PID_FILE"
    info "Test server started (PID: $server_pid)"

    log "Waiting for server to become ready..."
    for _ in {1..30}; do
        if curl -sSf http://localhost:3001 >/dev/null 2>&1; then
            success "Server is accepting connections on http://localhost:3001"
            break
        fi
        sleep 1
    done

    if ! curl -sSf http://localhost:3001 >/dev/null 2>&1; then
        error "Server failed to start within 30 seconds"
        kill "$server_pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        exit 1
    fi

    log "Validating API endpoints..."
    local login_response login_token categories_response expenses_response available_years year month_label enc_month_label

    login_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"username":"Diptanshu", "password":"finance"}' \
        http://localhost:3001/api/v1/auth/login)
    login_token=$(echo "$login_response" | jq -r '.token // empty')

    if [ -z "$login_token" ]; then
        error "Login API failed (expected token)"
        exit 1
    fi
    success "Login API working"

    categories_response=$(curl -s -H "Authorization: Bearer $login_token" http://localhost:3001/api/v1/categories)
    if echo "$categories_response" | jq -e '.[] | has("id")' >/dev/null 2>&1; then
        success "Categories API working"
    else
        error "Categories API failed"
        exit 1
    fi

    expenses_response=$(curl -s -H "Authorization: Bearer $login_token" http://localhost:3001/api/v1/expenses)
    if echo "$expenses_response" | jq -e '.[] | has("id")' >/dev/null 2>&1; then
        success "Expenses API working"
    else
        error "Expenses API failed"
        exit 1
    fi

    available_years=$(curl -fsS "http://localhost:3001/api/v1/reports/available_years" -H "Authorization: Bearer $login_token")
    year=$(echo "$available_years" | jq -r '.years[0] // 2025')
    month_label=$(date "+%B %Y")
    enc_month_label=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$month_label")

    if curl -fsS "http://localhost:3001/api/v1/reports/year?year=$year" -H "Authorization: Bearer $login_token" >/dev/null; then
        success "Year report ($year) OK"
    else
        error "Year report failed"
        exit 1
    fi

    if curl -fsS "http://localhost:3001/api/v1/reports/month?month=$enc_month_label" -H "Authorization: Bearer $login_token" >/dev/null; then
        success "Month report ($month_label) OK"
    else
        error "Month report failed"
        exit 1
    fi

    echo ""
    echo "======================================"
    success "Test server ready!"
    echo "======================================"
    echo ""
    info "Server URL: http://localhost:3001"
    info "PID: $server_pid (stored at $PID_FILE)"
    info "Logs: $SERVER_LOG"
    echo ""
    info "Stop with: $(basename "$0") stop"
    echo ""
}

stop_server() {
    local skip_cleanup="$1"

    echo ""
    echo "======================================"
    echo "🧹 Stopping Test Server"
    echo "======================================"
    echo ""

    if [ -f "$PID_FILE" ]; then
        local pid
        pid="$(cat "$PID_FILE")"
        if kill -0 "$pid" 2>/dev/null; then
            log "Stopping test server (PID: $pid)..."
            kill -15 "$pid" 2>/dev/null || true
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                warn "Server did not stop gracefully, forcing termination..."
                kill -9 "$pid" 2>/dev/null || true
            fi
            success "Test server stopped"
        else
            info "Server PID $pid not running"
        fi
        rm -f "$PID_FILE"
    else
        if pid="$(is_server_running)"; then
            log "Found server on port 3001 (PID: $pid)"
            kill -15 "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
            success "Server process terminated"
        else
            info "No server process detected on port 3001"
        fi
    fi

    shutdown_simulators

    if [ "$skip_cleanup" = "false" ]; then
        clean_logs
    else
        warn "Skipping log cleanup (--no-cleanup supplied)"
    fi

    echo ""
    echo "======================================"
    success "Shutdown complete!"
    echo "======================================"
    echo ""
}

status_server() {
    echo ""
    echo "======================================"
    echo "📈 Test Server Status"
    echo "======================================"
    echo ""

    if pid="$(is_server_running)"; then
        success "Server running on port 3001 (PID: $pid)"
    else
        warn "Server is not running"
    fi

    if xcrun simctl list devices | grep -E "Booted" >/dev/null 2>&1; then
        info "Booted simulators:"
        xcrun simctl list devices | grep -E "Booted"
    else
        success "No simulators currently booted"
    fi

    echo ""
    echo "Logs: $SERVER_LOG"
    echo ""
}

COMMAND="${1:-help}"
shift || true

SKIP_CLEANUP=false
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-cleanup|--no_cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

case "$COMMAND" in
    start)
        if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
            warn "Ignoring unsupported options for 'start': ${EXTRA_ARGS[*]}"
        fi
        start_server
        ;;
    stop)
        if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
            warn "Ignoring unsupported options for 'stop': ${EXTRA_ARGS[*]}"
        fi
        stop_server "$SKIP_CLEANUP"
        ;;
    restart)
        if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
            warn "Ignoring unsupported options for 'restart': ${EXTRA_ARGS[*]}"
        fi
        stop_server "$SKIP_CLEANUP"
        start_server
        ;;
    status)
        if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
            warn "Ignoring unsupported options for 'status': ${EXTRA_ARGS[*]}"
        fi
        status_server
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac








