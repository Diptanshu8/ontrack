#!/bin/bash

# Cleanup Test Server Script
# Stops test server and cleans up resources

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
echo "🧹 Cleaning Up Test Server"
echo "======================================"
echo ""

# Kill server by PID file
if [ -f /tmp/test_server.pid ]; then
    PID=$(cat /tmp/test_server.pid)
    if kill -0 $PID 2>/dev/null; then
        log "Stopping test server (PID: $PID)..."
        kill -15 $PID 2>/dev/null || true
        sleep 2
        if kill -0 $PID 2>/dev/null; then
            warn "Server didn't stop gracefully, forcing..."
            kill -9 $PID 2>/dev/null || true
        fi
        success "Test server stopped"
    else
        info "Server (PID: $PID) not running"
    fi
    rm /tmp/test_server.pid
else
    # Fallback: kill by port
    if lsof -i :3001 -t >/dev/null 2>&1 ; then
        PID=$(lsof -i :3001 -t)
        log "Found server on port 3001 (PID: $PID)"
        kill -9 $PID 2>/dev/null || true
        success "Killed server on port 3001"
    else
        info "No server running on port 3001"
    fi
fi

# Shut down all simulators
log "Shutting down simulators..."
xcrun simctl shutdown all 2>/dev/null || true
success "Simulators shut down"

# Optional: Clean up logs (only if tests passed)
if [ "$1" == "--clean-logs" ]; then
    log "Cleaning up logs..."
    rm -f /tmp/test_server.log 2>/dev/null || true
    rm -f /tmp/ontrack_full_test_*.log 2>/dev/null || true
    success "Logs cleaned"
fi

echo ""
echo "======================================"
success "Cleanup complete!"
echo "======================================"
echo ""

