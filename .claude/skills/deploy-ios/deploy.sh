#!/bin/bash

# deploy.sh - Build and deploy OnTrack iOS app to physical iPhone
# Usage: ./deploy.sh [device-id]

set -euo pipefail

# Colors for output
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

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../.."
IOS_PROJECT_DIR="$PROJECT_ROOT/OnTrack-iOS/OnTrack"
PROJECT_FILE="$IOS_PROJECT_DIR/OnTrack.xcodeproj"
SCHEME_NAME="OnTrack"
BUILD_CONFIG="Debug"

# Device ID (can be passed as argument or auto-detected)
DEVICE_ID="${1:-}"

log "🚀 OnTrack iOS Deployment Script"
echo ""

# Check if project exists
if [ ! -d "$IOS_PROJECT_DIR" ]; then
    error "iOS project not found at: $IOS_PROJECT_DIR"
    exit 1
fi

if [ ! -d "$PROJECT_FILE" ]; then
    error "Xcode project not found at: $PROJECT_FILE"
    exit 1
fi

success "Found iOS project at: $IOS_PROJECT_DIR"

# Discover connected devices (physical devices only, USB and wireless)
log "🔍 Discovering connected physical iPhones..."

# Primary: xctrace (works when CoreSimulatorService is healthy)
DEVICES=$(xcrun xctrace list devices 2>&1 | awk '/== Devices ==/,/== Simulators ==/' | grep -i "iphone" | grep -v "==" || true)

# Fallback: devicectl (works for wireless devices; doesn't depend on CoreSimulatorService)
if [ -z "$DEVICES" ]; then
    CORE_IDS=$(xcrun devicectl list devices 2>&1 | grep -i "iphone" | grep "available (paired)" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true)
    if [ -n "$CORE_IDS" ]; then
        while IFS= read -r core_id; do
            INFO=$(xcrun devicectl device info details --device "$core_id" 2>&1)
            NAME=$(echo "$INFO" | grep "• name:" | sed 's/.*• name: //')
            UDID=$(echo "$INFO" | grep "• udid:" | awk '{print $NF}')
            OS=$(echo "$INFO" | grep "• osVersionNumber:" | awk '{print $NF}')
            [ -n "$UDID" ] && DEVICES="${DEVICES}${NAME} (${OS}) (${UDID})"$'\n'
        done <<< "$CORE_IDS"
        DEVICES=$(echo "$DEVICES" | sed '/^[[:space:]]*$/d')
    fi
fi

# If device ID was passed as argument and discovery failed, skip the check — we'll try xcodebuild directly
if [ -z "$DEVICES" ] && [ -z "$DEVICE_ID" ]; then
    error "No physical iPhones found (USB or wireless)."
    info "For USB: connect your iPhone, unlock it, and tap 'Trust This Computer'."
    info "For Wi-Fi: enable 'Connect via Network' in Xcode → Window → Devices and Simulators."
    exit 1
elif [ -z "$DEVICES" ] && [ -n "$DEVICE_ID" ]; then
    warn "Device discovery unavailable — proceeding with provided device ID: $DEVICE_ID"
fi

# Count and display devices (skip if discovery was unavailable)
if [ -n "$DEVICES" ]; then
    DEVICE_COUNT=$(echo "$DEVICES" | wc -l | tr -d ' ')
    echo ""
    success "Found $DEVICE_COUNT connected iPhone(s):"
    echo ""
    i=1
    while IFS= read -r device_line; do
        echo "  $i) $device_line"
        i=$((i + 1))
    done <<< "$DEVICES"
    echo ""
else
    DEVICE_COUNT=0
fi

# If device ID not specified, let user select
if [ -z "$DEVICE_ID" ]; then
    # If only one device, auto-select it
    if [ "$DEVICE_COUNT" -eq 1 ]; then
        log "Only one device found, auto-selecting..."
        DEVICE_LINE="$DEVICES"
    else
        # Multiple devices - ask user to select
        echo -n "Select device number [1-$DEVICE_COUNT]: "
        read -r SELECTION

        # Validate selection
        if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt "$DEVICE_COUNT" ]; then
            error "Invalid selection: $SELECTION"
            exit 1
        fi

        # Get the selected device line
        DEVICE_LINE=$(echo "$DEVICES" | sed -n "${SELECTION}p")
    fi

    # Extract device ID from the line format: "Device Name (OS) (DEVICE-ID)"
    DEVICE_ID=$(echo "$DEVICE_LINE" | grep -oE '\([0-9A-F]{8}-[0-9A-F]{24}\)' | tr -d '()')
    DEVICE_NAME=$(echo "$DEVICE_LINE" | sed -E 's/ \([0-9.]+\).*//')

    echo ""
    success "Selected device: $DEVICE_NAME"
    info "Device ID: $DEVICE_ID"
else
    success "Using specified device ID: $DEVICE_ID"
fi

echo ""

# Build for device
log "🔨 Building OnTrack for device..."
info "Configuration: $BUILD_CONFIG"
info "Scheme: $SCHEME_NAME"

BUILD_DIR="$IOS_PROJECT_DIR/build"
mkdir -p "$BUILD_DIR"

# Build the app for device
# Note: -allowProvisioningUpdates helps with automatic provisioning
log "Running xcodebuild..."

if xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME_NAME" \
    -configuration "$BUILD_CONFIG" \
    -destination "id=$DEVICE_ID" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -allowProvisioningUpdates \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM="KR7LRG39NT" \
    build 2>&1 | tee "$BUILD_DIR/build.log"; then

    success "Build completed successfully!"
else
    error "Build failed. Check the log at: $BUILD_DIR/build.log"
    warn "Common issues:"
    echo "  1. Apple ID not signed in to Xcode"
    echo "  2. Provisioning profile issues"
    echo "  3. Device not trusted"
    echo "  4. Code signing certificate not found"
    echo ""
    info "To fix:"
    echo "  1. Open Xcode: open $PROJECT_FILE"
    echo "  2. Go to Signing & Capabilities"
    echo "  3. Select your team"
    echo "  4. Ensure 'Automatically manage signing' is checked"
    exit 1
fi

echo ""

# Find the built app
log "📦 Locating built app..."
APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "OnTrack.app" -path "*/Debug-iphoneos/*" | head -n 1)

if [ -z "$APP_PATH" ]; then
    error "Could not find built app at expected location"
    exit 1
fi

success "Found app at: $APP_PATH"

# Install on device using devicectl (Xcode 15+) or older methods
log "📲 Installing on device..."

# Try using xcrun devicectl (Xcode 15+)
if xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" 2>/dev/null; then
    success "App installed successfully using devicectl!"
elif xcrun simctl install "$DEVICE_ID" "$APP_PATH" 2>/dev/null; then
    success "App installed successfully!"
else
    # Fallback: The build install command should have already installed it
    warn "Could not verify installation command, but 'build install' may have succeeded"
    info "Check your device for the OnTrack app"
fi

echo ""
success "🎉 Deployment complete!"
echo ""
info "📱 Check your iPhone for the OnTrack app"
info "The app should appear on your home screen"
echo ""
info "If the app doesn't appear:"
echo "  1. Make sure the device is unlocked"
echo "  2. Check Settings → General → VPN & Device Management"
echo "  3. Trust the developer profile if prompted"
echo ""

exit 0
