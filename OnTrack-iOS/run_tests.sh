#!/bin/bash

# OnTrack iOS Test Runner with Real-Time Logging
# Usage: ./run_tests.sh [test_suite_name]

cd "$(dirname "$0")/OnTrack"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================"
echo "🧪 OnTrack iOS Automated Tests"
echo "======================================"
echo ""

# Check if test server is running
echo -n "🔍 Checking test server (localhost:3001)... "
if curl -s http://localhost:3001/api/v1/categories > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not running!${NC}"
    echo ""
    echo "Starting test server..."
    cd ../..
    RAILS_ENV=test bundle exec rails s -b 0.0.0.0 -p 3001 > log/test_server.log 2>&1 &
    TEST_SERVER_PID=$!
    echo "Test server PID: $TEST_SERVER_PID"
    sleep 5
    cd OnTrack-iOS/OnTrack
fi

echo ""

# Determine which tests to run
if [ -z "$1" ]; then
    TEST_TARGET="OnTrackUITests"
    echo "📋 Running all tests..."
else
    TEST_TARGET="OnTrackUITests/$1"
    echo "📋 Running: $1"
fi

echo ""
echo "======================================"
echo "🚀 Starting Test Execution"
echo "======================================"
echo ""

# Run tests with real-time output
xcodebuild test \
    -project OnTrack.xcodeproj \
    -scheme OnTrack \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
    -parallel-testing-enabled NO \
    -only-testing:$TEST_TARGET 2>&1 | \
    while IFS= read -r line; do
        # Test suite started
        if echo "$line" | grep -q "Test Suite.*started"; then
            suite=$(echo "$line" | sed -n "s/.*Test Suite '\(.*\)' started.*/\1/p")
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}📦 Test Suite: $suite${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        fi
        
        # Test case started
        if echo "$line" | grep -q "Test Case.*started"; then
            test=$(echo "$line" | sed -n "s/.*Test Case '-\[\(.*\)\]' started.*/\1/p")
            echo -e "${YELLOW}  ▶️  $test${NC}"
        fi
        
        # Test case passed
        if echo "$line" | grep -q "Test Case.*passed"; then
            test=$(echo "$line" | sed -n "s/.*Test Case '-\[\(.*\)\]' passed.*/\1/p")
            time=$(echo "$line" | sed -n "s/.*(\(.*\) seconds).*/\1/p")
            echo -e "${GREEN}  ✅ $test ${NC}(${time}s)"
        fi
        
        # Test case failed
        if echo "$line" | grep -q "Test Case.*failed"; then
            test=$(echo "$line" | sed -n "s/.*Test Case '-\[\(.*\)\]' failed.*/\1/p")
            time=$(echo "$line" | sed -n "s/.*(\(.*\) seconds).*/\1/p")
            echo -e "${RED}  ❌ $test ${NC}(${time}s)"
        fi
        
        # Print statements from tests (our custom logs)
        if echo "$line" | grep -q "🧪\|✅\|❌\|📱\|🔐\|📡\|🧹"; then
            echo "     $line"
        fi
        
        # Build status
        if echo "$line" | grep -q "BUILD SUCCEEDED"; then
            echo -e "${GREEN}✅ BUILD SUCCEEDED${NC}"
        fi
        
        if echo "$line" | grep -q "TEST SUCCEEDED"; then
            echo ""
            echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║   🎉 ALL TESTS PASSED! 🎉          ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
        fi
        
        if echo "$line" | grep -q "TEST FAILED"; then
            echo ""
            echo -e "${RED}╔════════════════════════════════════╗${NC}"
            echo -e "${RED}║   ⚠️  TESTS FAILED  ⚠️              ║${NC}"
            echo -e "${RED}╚════════════════════════════════════╝${NC}"
        fi
        
        # Errors and failures
        if echo "$line" | grep -q "XCTAssertTrue failed"; then
            msg=$(echo "$line" | sed -n 's/.*XCTAssertTrue failed - \(.*\)/\1/p')
            echo -e "${RED}     ⚠️  Assertion: $msg${NC}"
        fi
    done

echo ""
echo "======================================"
echo "📊 Test Execution Complete"
echo "======================================"

# Show test server log tail
echo ""
echo "📝 Recent test server logs:"
tail -20 ../../log/test_server.log | grep -E "(Started|Processing|Completed|401|500)" | tail -10

