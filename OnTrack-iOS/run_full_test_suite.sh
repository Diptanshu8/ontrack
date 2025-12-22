#!/bin/bash

# Full Test Suite Runner
# Orchestrates: test_server.sh start → test.sh --suite → test_server.sh stop

set -e

SCRIPT_DIR="/Users/djamgade/personal/ontrack/ontrack/OnTrack-iOS"
SERVER_CMD="$SCRIPT_DIR/test_server.sh"
TEST_CMD="$SCRIPT_DIR/test.sh"

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

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Parse arguments
SERIAL_MODE=false
VERBOSE_MODE=false
COVERAGE_MODE=false
ISOLATED_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--serial)
            SERIAL_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        -c|--coverage)
            COVERAGE_MODE=true
            shift
            ;;
        -i|--isolated)
            ISOLATED_MODE=true
            shift
            ;;
        -h|--help)
            echo ""
            echo "Usage: $0 [--serial] [--verbose] [--coverage] [--isolated]"
            echo ""
            echo "Options:"
            echo "  -s, --serial    Run tests serially (no parallel execution)"
            echo "  -v, --verbose   Show verbose output"
            echo "  -c, --coverage  Generate coverage report (full suite only)"
            echo "  -i, --isolated  Run full suite in isolated mode"
            echo "  -h, --help      Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo ""
echo "======================================"
echo "🚀 OnTrack Full Test Suite"
echo "======================================"
echo "Serial Mode:  $([ "$SERIAL_MODE" = true ] && echo "Yes" || echo "No")"
echo "Verbose:      $([ "$VERBOSE_MODE" = true ] && echo "Yes" || echo "No")"
echo "Coverage:     $([ "$COVERAGE_MODE" = true ] && echo "Yes" || echo "No")"
echo "Isolated:     $([ "$ISOLATED_MODE" = true ] && echo "Yes" || echo "No")"
echo ""

# Step 1: Start test server
log "STEP 1: Starting test server..."
"$SERVER_CMD" start
echo ""

# Step 2: Run tests
log "STEP 2: Running tests..."
info "Invoking $TEST_CMD --suite"
TEST_ARGS=(--suite)
if [ "$SERIAL_MODE" = true ]; then
    TEST_ARGS+=("--serial")
fi
if [ "$VERBOSE_MODE" = true ]; then
    TEST_ARGS+=("--verbose")
fi
if [ "$COVERAGE_MODE" = true ]; then
    TEST_ARGS+=("--coverage")
fi
if [ "$ISOLATED_MODE" = true ]; then
    TEST_ARGS+=("--isolated")
fi

set +e
"$TEST_CMD" "${TEST_ARGS[@]}"
TEST_EXIT_CODE=$?
set -e
echo ""

# Step 3: Cleanup
log "STEP 3: Cleaning up..."
"$SERVER_CMD" stop
echo ""

echo "======================================"
if [ $TEST_EXIT_CODE -eq 0 ]; then
    success "FULL TEST SUITE PASSED! 🎉"
    exit 0
else
    error "SOME TESTS FAILED"
    exit 1
fi
