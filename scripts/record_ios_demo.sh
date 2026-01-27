#!/bin/bash

# record_ios_demo.sh
# Automates recording the iOS Simulator while running the VideoDemoTest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
IOS_DIR="$PROJECT_ROOT/OnTrack-iOS"
OUTPUT_FILE="$PROJECT_ROOT/ontrack_ios_demo.mp4"
TEST_IDENTIFIER="VideoDemoTest/testVideoWalkthrough"

# 1. Boot Simulator
echo "📱 Booting Simulator (iPhone 17)..."
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator

# 2. Wait for Simulator to be ready
echo "⏳ Waiting for Simulator..."
xcrun simctl bootstatus "iPhone 17"
sleep 5

# 3. Start Recording in Background
echo "🎥 Starting Recording to $OUTPUT_FILE..."
# Remove old file if exists
rm -f "$OUTPUT_FILE"
# Start recording (use --force to overwrite if needed, though we rm'd it)
xcrun simctl io "iPhone 17" recordVideo --codec=h264 --mask=black "$OUTPUT_FILE" &
RECORD_PID=$!

echo "✅ Recording started (PID: $RECORD_PID)"

# 4. Run the specific Test Case
echo "🚀 Running VideoDemoTest..."
# We use the existing test.sh script but point it to our specific test
"$IOS_DIR/test.sh" "$TEST_IDENTIFIER" --verbose --serial

TEST_EXIT_CODE=$?

# 5. Stop Recording
echo "🛑 Stopping Recording..."
# Sending SIGINT (Ctrl+C) to the recording process saves the file gracefully
kill -SIGINT "$RECORD_PID"
sleep 5
wait "$RECORD_PID" || true

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ Success! Video saved to: $OUTPUT_FILE"
else
    echo "⚠️  Test failed, but video was saved to: $OUTPUT_FILE"
fi
