#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROJECT="$PROJECT_ROOT/OnTrack-iOS/OnTrack/OnTrack.xcodeproj"
BUILD_DIR="/tmp/OnTrackSimBuild"
BUNDLE_ID="com.djamgade.personal.OnTrack"

# Find a booted iPhone simulator, or fall back to first available iPhone
DEVICE_ID=$(xcrun simctl list devices --json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
# Prefer already-booted iPhones
for runtime, devices in data['devices'].items():
    for d in devices:
        if 'iPhone' in d.get('name', '') and d.get('state') == 'Booted' and not d.get('availabilityError'):
            print(d['udid']); sys.exit(0)
# Fall back to first available (non-booted) iPhone
for runtime, devices in data['devices'].items():
    for d in devices:
        if 'iPhone' in d.get('name', '') and d.get('isAvailable', False):
            print(d['udid']); sys.exit(0)
sys.exit(1)
" 2>/dev/null || echo "")

if [ -z "${DEVICE_ID:-}" ]; then
    echo "❌ No iPhone simulator found. Open Xcode → Window → Devices and Simulators to create one."
    exit 1
fi

DEVICE_NAME=$(xcrun simctl list devices --json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d.get('udid') == '$DEVICE_ID':
            print(d['name']); sys.exit(0)
" 2>/dev/null || echo "Unknown")

echo "▶ Using simulator: $DEVICE_NAME ($DEVICE_ID)"
echo ""

echo "▶ Building for simulator..."
xcodebuild build \
    -project "$PROJECT" \
    -scheme OnTrack \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath "$BUILD_DIR" \
    -quiet
echo "✅ Build succeeded"

echo "▶ Booting simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
open -a Simulator
sleep 2

echo "▶ Installing app..."
xcrun simctl install "$DEVICE_ID" "$BUILD_DIR/Build/Products/Debug-iphonesimulator/OnTrack.app"
echo "✅ App installed"

echo "▶ Configuring server URL to localhost:3001..."
CONTAINER=$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data 2>/dev/null || echo "")
if [ -n "$CONTAINER" ]; then
    PLIST="$CONTAINER/Library/Preferences/${BUNDLE_ID}.plist"
    /usr/libexec/PlistBuddy -c "Set :serverBaseURL http://localhost:3001/api/v1" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :serverBaseURL string http://localhost:3001/api/v1" "$PLIST"
    echo "✅ Server URL set"
else
    echo "⚠️  Could not find app container — server URL not configured. Use Server Settings in the app."
fi

echo "▶ Launching app..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo ""
echo "✅ App launched on $DEVICE_NAME!"
echo ""

echo "▶ Checking test server on :3001..."
if curl -s http://localhost:3001/api/v1/auth/validate >/dev/null 2>&1; then
    echo "✅ Test server already running on :3001"
else
    bash "$PROJECT_ROOT/OnTrack-iOS/test_server.sh" start
    echo "✅ Test server running on :3001"
fi
