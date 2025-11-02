#!/bin/bash

# Run each test in complete isolation - boot sim, run test, kill sim

LOG_FILE="/tmp/ontrack_isolated_tests.log"
SIMULATOR="iPhone 17"

echo "=====================================" | tee $LOG_FILE
echo "🧪 OnTrack iOS - Isolated Test Runner" | tee -a $LOG_FILE
echo "=====================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# List of all tests to run
TESTS=(
    "SimpleLoginTest/testQuickLogin"
    "LoginTest/testDashboardAppearsAfterLogin"
    "LoginTest/testLogout"
    "CategoryTest/testOpenCategorySidePanel"
    "CategoryTest/testCloseCategorySidePanel"
    "NavigationTest/testNavigateToDashboard"
    "NavigationTest/testNavigateToInsights"
    "NavigationTest/testNavigateToHistory"
    "NavigationTest/testNavigateBetweenAllTabs"
)

PASSED=0
FAILED=0

for TEST in "${TESTS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a $LOG_FILE
    echo "🧪 Test: $TEST" | tee -a $LOG_FILE
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a $LOG_FILE
    
    # Kill all simulators
    echo "  🔄 Shutting down all simulators..." | tee -a $LOG_FILE
    xcrun simctl shutdown all 2>&1 >> $LOG_FILE
    sleep 2
    
    # Boot simulator and open Simulator.app
    echo "  🚀 Booting $SIMULATOR..." | tee -a $LOG_FILE
    xcrun simctl boot "$SIMULATOR" 2>&1 >> $LOG_FILE
    open -a Simulator
    sleep 5
    echo "  ✅ Simulator window opened" | tee -a $LOG_FILE
    
    # Run the test
    echo "  ▶️  Running test..." | tee -a $LOG_FILE
    cd "$(dirname "$0")/OnTrack"
    
    xcodebuild test \
        -project OnTrack.xcodeproj \
        -scheme OnTrack \
        -destination "platform=iOS Simulator,name=$SIMULATOR,OS=latest" \
        -parallel-testing-enabled NO \
        -only-testing:OnTrackUITests/$TEST \
        2>&1 | tee -a $LOG_FILE | grep -E "(Test Case.*passed|Test Case.*failed|error:|warning:)" | while read line; do
            echo "     $line" | tee -a $LOG_FILE
        done
    
    # Check result
    if grep -q "Test Case.*$TEST.*passed" $LOG_FILE | tail -20; then
        echo "  ✅ PASSED" | tee -a $LOG_FILE
        ((PASSED++))
    else
        echo "  ❌ FAILED" | tee -a $LOG_FILE
        ((FAILED++))
    fi
    
    # Kill simulator
    echo "  🛑 Shutting down simulator..." | tee -a $LOG_FILE
    xcrun simctl shutdown all 2>&1 >> $LOG_FILE
    sleep 2
    
    echo "" | tee -a $LOG_FILE
done

echo "=====================================" | tee -a $LOG_FILE
echo "📊 Test Results Summary" | tee -a $LOG_FILE
echo "=====================================" | tee -a $LOG_FILE
echo "  ✅ Passed: $PASSED" | tee -a $LOG_FILE
echo "  ❌ Failed: $FAILED" | tee -a $LOG_FILE
echo "  📁 Full logs: $LOG_FILE" | tee -a $LOG_FILE
echo "=====================================" | tee -a $LOG_FILE

