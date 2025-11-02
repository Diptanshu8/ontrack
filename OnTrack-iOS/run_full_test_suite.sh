#!/bin/bash

# Full Test Suite Runner for OnTrack iOS App
# This script handles the complete test lifecycle with proper validation

# Initialize rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - bash)"

PROJECT_ROOT="/Users/djamgade/personal/ontrack/ontrack"
IOS_ROOT="$PROJECT_ROOT/OnTrack-iOS/OnTrack"
LOG_FILE="/tmp/ontrack_full_test_$(date +%Y%m%d_%H%M%S).log"
SIMULATOR_NAME="iPhone 17"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Usage function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Description:"
    echo "  Runs the complete OnTrack iOS test suite with:"
    echo "    - Automatic test database setup"
    echo "    - Test server validation"
    echo "    - All UI tests"
    echo "    - Automatic cleanup"
    echo ""
    echo "Note: Simulator window will be visible during tests (required by Xcode)"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

log() {
    echo -e "${BLUE}▶${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

echo ""
echo "======================================"
echo "🚀 OnTrack Full Test Suite"
echo "======================================"
info "Log file: $LOG_FILE"
echo ""

# ============================================
# STEP 1: Cleanup
# ============================================
log "STEP 1: Cleaning up..."

if lsof -ti:3001 > /dev/null 2>&1; then
    lsof -ti:3001 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

xcrun simctl shutdown all 2>/dev/null || true
sleep 2
success "Cleanup complete"
echo ""

# ============================================
# STEP 2: Setup test database
# ============================================
log "STEP 2: Setting up test database..."

cd "$PROJECT_ROOT"

dropdb ontrack_test 2>&1 >> "$LOG_FILE" || true
createdb ontrack_test 2>&1 >> "$LOG_FILE"
pg_dump ontrack_development 2>&1 | psql ontrack_test 2>&1 >> "$LOG_FILE"

if [ $? -eq 0 ]; then
    success "Test database ready"
else
    error "Failed to setup test database"
    exit 1
fi
echo ""

# ============================================
# STEP 3: Start and validate test server
# ============================================
log "STEP 3: Starting test server on port 3001..."

RAILS_ENV=test bundle exec rails server -p 3001 > /tmp/test_server.log 2>&1 &
TEST_SERVER_PID=$!

# Wait for server
MAX_WAIT=30
WAITED=0
while ! curl -s http://localhost:3001 > /dev/null 2>&1; do
    sleep 1
    WAITED=$((WAITED + 1))
    if [ $WAITED -ge $MAX_WAIT ]; then
        error "Test server failed to start"
        cat /tmp/test_server.log | tail -20
        exit 1
    fi
done

success "Test server started (PID: $TEST_SERVER_PID)"

# ============================================
# STEP 4: Validate server health
# ============================================
log "STEP 4: Validating server health..."

# Test 1: Login API
log "  → Testing login API..."
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:3001/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"Diptanshu","password":"finance"}')
LOGIN_CODE=$(echo "$LOGIN_RESPONSE" | tail -1)

if [ "$LOGIN_CODE" = "200" ]; then
    TOKEN=$(echo "$LOGIN_RESPONSE" | head -1 | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    success "  Login API working (token received)"
else
    error "  Login API failed (HTTP $LOGIN_CODE)"
    echo "$LOGIN_RESPONSE"
    kill $TEST_SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test 2: Categories API
log "  → Testing categories API..."
CATEGORIES_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/api/v1/categories \
    -H "Authorization: Bearer $TOKEN")

if [ "$CATEGORIES_CODE" = "200" ]; then
    success "  Categories API working"
else
    error "  Categories API failed (HTTP $CATEGORIES_CODE)"
    kill $TEST_SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test 3: Expenses API
log "  → Testing expenses API..."
EXPENSES_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/api/v1/expenses \
    -H "Authorization: Bearer $TOKEN")

if [ "$EXPENSES_CODE" = "200" ]; then
    success "  Expenses API working"
else
    error "  Expenses API failed (HTTP $EXPENSES_CODE)"
    kill $TEST_SERVER_PID 2>/dev/null || true
    exit 1
fi

success "Server health check passed"
echo ""

# ============================================
# STEP 5: Build test target
# ============================================
log "STEP 5: Building test target..."

cd "$IOS_ROOT"

xcodebuild build-for-testing \
    -project OnTrack.xcodeproj \
    -scheme OnTrack \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
    > /tmp/xcode_build.log 2>&1

if [ $? -ne 0 ]; then
    error "Build failed!"
    grep -E "error:" /tmp/xcode_build.log | tail -10
    kill $TEST_SERVER_PID 2>/dev/null || true
    exit 1
fi

success "Build succeeded"
echo ""

# ============================================
# STEP 6: Run UI tests
# ============================================
log "STEP 6: Running UI tests..."

# Boot simulator and open Simulator.app
SIMULATOR_ID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -v "unavailable" | head -1 | grep -o '[A-F0-9-]\{36\}')
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
sleep 3

open -a Simulator
info "Simulator window opened"
sleep 2

echo ""

# Run tests with real-time filtered output (parallel testing enabled)
xcodebuild test-without-building \
    -project OnTrack.xcodeproj \
    -scheme OnTrack \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
    -parallel-testing-enabled YES \
    2>&1 | tee -a "$LOG_FILE" | while IFS= read -r line; do
        # Show test progress in real-time
        if echo "$line" | grep -qE "(Test Suite.*started|Test Suite.*passed|Test Suite.*failed|Test Case.*started|Test Case.*passed|Test Case.*failed|Executed.*tests|🧪|📋|📝|💰|🎨|💾|✅|↩️|⚠️|✏️|📜|🧹|💵|🔍|🗑️)"; then
            echo "$line"
        fi
    done

TEST_EXIT_CODE=${PIPESTATUS[0]}

echo ""

# ============================================
# STEP 7: Cleanup
# ============================================
log "STEP 7: Cleaning up..."

kill $TEST_SERVER_PID 2>/dev/null || true
xcrun simctl shutdown all 2>/dev/null || true

success "Cleanup complete"
echo ""
echo "======================================"

# Print summary
if [ $TEST_EXIT_CODE -eq 0 ]; then
    success "ALL TESTS PASSED! 🎉"
    echo ""
    
    # Cleanup logs on success
    info "Cleaning up logs..."
    rm -f "$LOG_FILE" /tmp/test_server.log /tmp/xcode_build.log 2>/dev/null
    success "Logs cleaned up"
    
    exit 0
else
    error "SOME TESTS FAILED"
    echo ""
    echo -e "${RED}Full log: $LOG_FILE${NC}"
    echo -e "${RED}Server log: /tmp/test_server.log${NC}"
    echo ""
    log "Failed tests:"
    grep -E "Test Case.*failed" "$LOG_FILE" | sed 's/^/  /'
    exit 1
fi
