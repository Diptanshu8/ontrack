# Preview OnTrack on Simulator

Builds the current code, installs it on the first available iPhone simulator, configures the server URL, and launches the app — all in one step.

## Steps

1. Run the preview script:
   ```bash
   bash .claude/skills/preview-simulator/preview.sh
   ```

2. The script will:
   - Discover the first booted iPhone simulator (or boot one if none is running)
   - Build the app for that simulator
   - Install the new build
   - Set `serverBaseURL` to `http://localhost:3001/api/v1` in UserDefaults
   - Launch the app and open the Simulator window

3. Report success and remind the user:
   - "✅ App launched on [device name]!"
   - Remind them the test server must be running: `bash OnTrack-iOS/test_server.sh start`

## Important Notes

- The test server must be running separately for the app to connect to data
- Server URL is set automatically — no manual configuration needed
- If the app shows "Request failed", check that the test server is running on port 3001
- After running UI tests, UserDefaults is cleared; this script re-applies the server URL

## Troubleshooting

- **"No iPhone simulator found"** — open Xcode → Window → Devices and Simulators and create an iPhone simulator
- **Build fails** — check that Xcode project at `OnTrack-iOS/OnTrack/OnTrack.xcodeproj` exists
- **App not connecting** — run `bash OnTrack-iOS/test_server.sh start` first
