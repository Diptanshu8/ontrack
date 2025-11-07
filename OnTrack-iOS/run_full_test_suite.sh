#!/bin/bash

# Full Test Suite Runner
# Orchestrates: start_test_server.sh → run_tests.sh → cleanup_test_server.sh

set -e

SCRIPT_DIR="/Users/djamgade/personal/ontrack/ontrack/OnTrack-iOS"

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
        -h|--help)
            echo ""
            echo "Usage: $0 [--serial] [--verbose]"
            echo ""
            echo "Options:"
            echo "  -s, --serial    Run tests serially (no parallel execution)"
            echo "  -v, --verbose   Show verbose output"
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
echo ""

# Step 1: Start test server
log "STEP 1: Starting test server..."
cd "$SCRIPT_DIR"
bash start_test_server.sh
if [ $? -ne 0 ]; then
    error "Failed to start test server"
    exit 1
fi
echo ""

# Step 2: Run tests
log "STEP 2: Running tests..."
info "Mode: $([ "$SERIAL_MODE" = true ] && echo "Serial" || echo "Parallel")"
info "Verbose: $([ "$VERBOSE_MODE" = true ] && echo "Yes" || echo "No")"
bash run_tests.sh $([ "$SERIAL_MODE" = true ] && echo "--serial") $([ "$VERBOSE_MODE" = true ] && echo "--verbose")
TEST_EXIT_CODE=$?
echo ""

# Step 3: Cleanup
log "STEP 3: Cleaning up..."
if [ $TEST_EXIT_CODE -eq 0 ]; then
    bash cleanup_test_server.sh --clean-logs
else
    bash cleanup_test_server.sh
fi
echo ""

echo "======================================"
if [ $TEST_EXIT_CODE -eq 0 ]; then
    success "FULL TEST SUITE PASSED! 🎉"
    exit 0
else
    error "SOME TESTS FAILED"
    exit 1
fi
