#!/bin/bash

# Single Test Runner with Real-Time Logging
# Run individual tests or test classes with live output

set -e

IOS_ROOT="/Users/djamgade/personal/ontrack/ontrack/OnTrack-iOS/OnTrack"
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
    echo ""
    echo "======================================"
    echo "🧪 OnTrack Single Test Runner"
    echo "======================================"
    echo ""
    echo "Usage: $0 [OPTIONS] [TEST_NAME]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -l, --list              List all available tests"
    echo "  -s, --serial            Run in serial mode (no parallel execution)"
    echo "  -v, --verbose           Show verbose output"
    echo ""
    echo "Examples:"
    echo "  $0 --list                                    # List all tests"
    echo "  $0 SimpleLoginTest                           # Run entire test class"
    echo "  $0 LoginTest/testLogout                      # Run specific test method"
    echo "  $0 --serial ValidationTests                  # Run class serially"
    echo "  $0 --verbose CategoryTest/testEditCategoryAllFields"
    echo ""
    echo "======================================"
    echo "📋 Use --list to see all available tests"
    echo "======================================"
    echo ""
}

# List all tests dynamically
list_tests() {
    echo ""
    echo "======================================"
    echo "📋 All Available Tests (Dynamically Generated)"
    echo "======================================"
    echo ""
    
    # Find all test files
    TEST_DIR="OnTrack/OnTrackUITests/Flows"
    
    if [ ! -d "$TEST_DIR" ]; then
        echo "❌ Error: Test directory not found: $TEST_DIR"
        exit 1
    fi
    
    # Get all test classes (match both *Test.swift and *Tests.swift)
    TEST_FILES=$(find "$TEST_DIR" -name "*Test*.swift" -type f | sort)
    
    if [ -z "$TEST_FILES" ]; then
        echo "❌ No test files found in $TEST_DIR"
        exit 1
    fi
    
    echo "Test Classes (run entire class):"
    for file in $TEST_FILES; do
        class_name=$(basename "$file" .swift)
        echo "  • $class_name"
    done
    echo ""
    
    echo "Individual Tests (run specific method):"
    echo ""
    
    # Parse each test file for test methods
    for file in $TEST_FILES; do
        class_name=$(basename "$file" .swift)
        
        # Extract test methods (functions starting with "func test")
        test_methods=$(grep -E "^\s*func test[A-Za-z0-9_]+\(\)" "$file" | sed -E 's/.*func (test[A-Za-z0-9_]+).*/\1/' | sort)
        
        if [ -n "$test_methods" ]; then
            echo "$class_name:"
            while IFS= read -r method; do
                echo "  • $class_name/$method"
            done <<< "$test_methods"
            echo ""
        fi
    done
    
    echo "======================================"
    echo ""
}

# Parse arguments
SERIAL_MODE=false
VERBOSE_MODE=false
TEST_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            list_tests
            exit 0
            ;;
        -s|--serial)
            SERIAL_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        *)
            TEST_NAME="$1"
            shift
            ;;
    esac
done

# Check if test name provided
if [ -z "$TEST_NAME" ]; then
    echo -e "${RED}❌ Error: No test name provided${NC}"
    echo ""
    echo "Run '$0 --help' for usage information"
    echo "Run '$0 --list' to see all available tests"
    exit 1
fi

# Check if test server is running
if ! lsof -i :3001 -t >/dev/null 2>&1 ; then
    echo -e "${RED}❌ Test server not running on port 3001${NC}"
    echo ""
    echo -e "${CYAN}ℹ️  Start server first: bash start_test_server.sh${NC}"
    exit 1
fi

echo ""
echo "======================================"
echo "🧪 Running Test: $TEST_NAME"
echo "======================================"
echo -e "${CYAN}ℹ️  Mode: $([ "$SERIAL_MODE" = true ] && echo "Serial" || echo "Parallel")${NC}"
echo -e "${CYAN}ℹ️  Verbose: $([ "$VERBOSE_MODE" = true ] && echo "Yes" || echo "No")${NC}"
echo -e "${GREEN}✅ Test server detected on port 3001${NC}"
echo ""

# Build test target
echo -e "${BLUE}▶${NC} Building test target..."
cd "$IOS_ROOT"
xcodebuild build-for-testing \
    -project OnTrack.xcodeproj \
    -scheme OnTrack \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
    > /tmp/xcode_build.log 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build succeeded${NC}"
else
    echo -e "${RED}❌ Build failed. Check /tmp/xcode_build.log${NC}"
    exit 1
fi
echo ""

# Boot simulator
echo -e "${BLUE}▶${NC} Preparing simulator..."
SIMULATOR_ID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep -v "unavailable" | head -1 | grep -o '[A-F0-9-]\{36\}')
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
sleep 2
open -a Simulator
echo -e "${CYAN}ℹ️  Simulator window opened${NC}"
sleep 2
echo ""

# Prepare xcodebuild command
PARALLEL_FLAG=""
if [ "$SERIAL_MODE" = true ]; then
    PARALLEL_FLAG="-parallel-testing-enabled NO"
else
    PARALLEL_FLAG="-parallel-testing-enabled YES"
fi

# Run test with real-time output using tee
echo -e "${BLUE}▶${NC} Running test..."
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

LOG_FILE="/tmp/single_test_$(date +%Y%m%d_%H%M%S).log"

if [ "$VERBOSE_MODE" = true ]; then
    # Verbose mode - show everything with unbuffered output
    xcodebuild test-without-building \
        -project OnTrack.xcodeproj \
        -scheme OnTrack \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
        -only-testing:OnTrackUITests/$TEST_NAME \
        $PARALLEL_FLAG \
        2>&1 | tee "$LOG_FILE"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
else
    # Normal mode - filter output for readability with unbuffered grep
    xcodebuild test-without-building \
        -project OnTrack.xcodeproj \
        -scheme OnTrack \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest" \
        -only-testing:OnTrackUITests/$TEST_NAME \
        $PARALLEL_FLAG \
        2>&1 | tee "$LOG_FILE" | grep --line-buffered -E "(Test Suite.*started|Test Suite.*passed|Test Suite.*failed|Test Case.*started|Test Case.*passed|Test Case.*failed|Testing started|Executed|🧪|📋|📝|💰|🎨|💾|✅|↩️|⚠️|✏️|📜|🧹|💵|🔍|🗑️|❌)"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Extract and display test results summary
echo -e "${CYAN}📊 Test Results Summary:${NC}"
echo ""
grep -E "(Test case.*passed|Test case.*failed)" "$LOG_FILE" | while IFS= read -r line; do
    if echo "$line" | grep -q "passed"; then
        echo -e "${GREEN}  ✅ $(echo "$line" | sed -E "s/.*Test case '([^']+)'.*/\1/")${NC}"
    else
        echo -e "${RED}  ❌ $(echo "$line" | sed -E "s/.*Test case '([^']+)'.*/\1/")${NC}"
    fi
done

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Print result
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ TEST PASSED! 🎉                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
else
    echo -e "${RED}╔════════════════════════════════════╗${NC}"
    echo -e "${RED}║   ❌ TEST FAILED                    ║${NC}"
    echo -e "${RED}╚════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${CYAN}ℹ️  Full log saved to: $LOG_FILE${NC}"
echo ""

exit $TEST_EXIT_CODE

