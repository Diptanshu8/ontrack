# Deploy iOS Skill

## Overview

This skill automatically discovers connected iPhones and deploys the OnTrack iOS app to your selected device.

## Usage

### In Claude Code

Simply invoke the skill:

```
/deploy-ios
```

Or ask Claude:

```
"Deploy the iOS app to my iPhone"
"Send the app to my phone"
"Install the iOS app on my device"
```

### From Command Line

You can also run the deployment script directly:

```bash
# Interactive mode (shows devices and lets you select)
bash .claude/skills/deploy-ios/deploy.sh

# Or specify device ID directly
bash .claude/skills/deploy-ios/deploy.sh 00008101-000A69292669003A
```

## How It Works

1. **Discovery**: Scans for connected physical iPhones using `xcrun xctrace`
2. **Selection**: Shows numbered list of devices for you to choose from
3. **Build**: Builds the OnTrack app for iOS using `xcodebuild`
4. **Deploy**: Installs the app on your selected iPhone
5. **Verify**: Confirms successful installation

## Requirements

- Xcode 15+ installed
- iPhone connected via USB (or on local network)
- Apple Developer account signed into Xcode
- Device must trust this Mac
- Valid provisioning profile

## Device Selection

When you run the skill:
- **Only physical devices** are shown (simulators are excluded)
- If **one device** is connected: Auto-selects it
- If **multiple devices** are connected: Shows numbered menu to choose
- The script displays device name, iOS version, and device ID

## Troubleshooting

### "No physical iPhones found"
- Connect iPhone via USB cable
- Unlock the device
- Tap "Trust This Computer" when prompted

### "Code signing failed"
1. Open project in Xcode: `open OnTrack-iOS/OnTrack/OnTrack.xcodeproj`
2. Select "OnTrack" target
3. Go to "Signing & Capabilities" tab
4. Sign in with your Apple ID
5. Select your team
6. Enable "Automatically manage signing"

### "Provisioning profile issues"
- Make sure your Apple ID is added to Xcode (Preferences → Accounts)
- Device must be registered with your Apple Developer account
- May need to download provisioning profiles

### "App doesn't appear on device"
- Check Settings → General → VPN & Device Management
- Trust the developer profile
- Device must be unlocked
- Wait a few seconds for app to install

## Files

- `SKILL.md` - Skill definition and instructions for Claude
- `deploy.sh` - Main deployment script
- `README.md` - This documentation

## Examples

### Example 1: Deploy to iPhone 12

```bash
/deploy-ios
# Shows: "Diptanshu's iPhone (26.2)"
# Select: 1
# Result: App builds and installs
```

### Example 2: Multiple Devices

```bash
/deploy-ios
# Shows:
#   1) Diptanshu's iPhone (26.2) (00008101-000A69292669003A)
#   2) iPhone (76) (26.2) (00008030-000538E10EDB402E)
# Select device number [1-2]: 1
```

## Notes

- The build configuration is set to "Debug" for faster builds
- Builds are stored in `OnTrack-iOS/OnTrack/build/`
- Build logs are saved to `build/build.log` for troubleshooting
- The script uses `-allowProvisioningUpdates` for automatic provisioning
- Works with both USB-connected and network-connected devices

## Future Enhancements

Potential improvements:
- [ ] Support for wireless deployment (no USB needed)
- [ ] Remember last selected device
- [ ] Build configuration selection (Debug/Release)
- [ ] Archive and export for TestFlight
- [ ] Deployment to multiple devices simultaneously
- [ ] Integration with network discovery (Bonjour/mDNS)
