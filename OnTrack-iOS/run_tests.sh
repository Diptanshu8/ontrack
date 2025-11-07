#!/bin/bash

# Run UI Tests Only
# Assumes test server is already running on port 3001
# Usage: ./run_tests.sh [--serial] [--verbose]

set -e

IOS_ROOT="/Users/djamgade/personal/ontrack/ontrack/OnTrack-iOS/OnTrack"
SIMULATOR_NAME="iPhone 17"
LOG_FILE="/tmp/ontrack_tests_$(date +%Y%m%d_%H%M%S).log"

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
            echo "Usage: $0 [OPTIONS]"
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
echo "🧪 Running UI Tests"
echo "======================================"
info "Mode: $([ "$SERIAL_MODE" = true ] && echo "Serial" || echo "Parallel")"
info "Verbose: $([ "$VERBOSE_MODE" = true ] && echo "Yes" || echo "No")"
info "Log file: $LOG_FILE"
echo ""

# Check if test server is running
if ! lsof -i :3001 -t >/dev/null 2>&1 ; then
    error "Test server not running on port 3001"
    echo ""
    info "Start server first: bash start_test_server.sh"
    exit 1
fi

success "Test server detected on port 3001"
echo ""

# Build test target
log "Building test target..."
cd "$IOS_ROOT"
xcodebuild build-for-testing \
    -project OnTrack.xcodeproj \
    -scheme OnTrack \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
    > /tmp/xcode_build.log 2>&1

if [ $? -eq 0 ]; then
    success "Build succeeded"
else
    error "Build failed. Check /tmp/xcode_build.log"
    exit 1
fi
echo ""

# Boot simulator and open window
log "Preparing simulator..."
SIMULATOR_ID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -v "unavailable" | head -1 | grep -o '[A-F0-9-]\{36\}')
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
sleep 2
open -a Simulator
info "Simulator window opened"
sleep 2
echo ""

# Prepare parallel flag
PARALLEL_FLAG=""
if [ "$SERIAL_MODE" = true ]; then
    PARALLEL_FLAG="-parallel-testing-enabled NO"
else
    PARALLEL_FLAG="-parallel-testing-enabled YES"
fi

# Run tests with real-time output
log "Running tests..."
echo ""

if [ "$VERBOSE_MODE" = true ]; then
    # Verbose mode - show everything with tee
    xcodebuild test-without-building \
        -project OnTrack.xcodeproj \
        -scheme OnTrack \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
        $PARALLEL_FLAG \
        2>&1 | tee "$LOG_FILE"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
else
    # Normal mode - filtered output with unbuffered grep
    xcodebuild test-without-building \
        -project OnTrack.xcodeproj \
        -scheme OnTrack \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
        $PARALLEL_FLAG \
        2>&1 | tee "$LOG_FILE" | grep --line-buffered -E "(Test Suite.*started|Test Suite.*passed|Test Suite.*failed|Test Case.*started|Test Case.*passed|Test Case.*failed|Testing started|Executed.*tests|🧪|📋|📝|💰|🎨|💾|✅|↩️|⚠️|✏️|📜|🧹|💵|🔍|🗑️)"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
fi

echo ""
echo "======================================"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    success "ALL TESTS PASSED! 🎉"
    echo ""
    info "Log: $LOG_FILE"
    exit 0
else
    error "SOME TESTS FAILED"
    echo ""
    error "Log: $LOG_FILE"
    echo ""
    log "Failed tests:"
    grep -E "Test Case.*failed" "$LOG_FILE" | sed 's/^/  /' || true
    exit 1
fi
