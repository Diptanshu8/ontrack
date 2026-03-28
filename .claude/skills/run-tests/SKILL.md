---
name: run-tests
description: Start the iOS test server and run the full UI test suite in serial mode. Optionally run a specific test class. Use when the user wants to run iOS tests or verify changes haven't broken anything.
user-invocable: true
allowed-tools: Bash(bash *), Bash(xcrun *), Bash(xcodebuild *)
argument-hint: "[TestClassName]"
---

# Run iOS UI Tests

Starts the test server and runs the full UI test suite in serial mode.

## Steps

1. **Ensure test server is running**
   ```bash
   bash OnTrack-iOS/test_server.sh status
   ```
   If not running, start it:
   ```bash
   bash OnTrack-iOS/test_server.sh start
   ```

2. **Run the tests**

   If $ARGUMENTS contains a test class name, run only that class:
   ```bash
   bash OnTrack-iOS/test.sh --serial $ARGUMENTS
   ```

   Otherwise run the full suite:
   ```bash
   bash OnTrack-iOS/test.sh --serial
   ```

3. **Report results**
   - Show pass/fail count
   - If any tests fail, show the failure message and which test failed
   - If all pass: "✅ All X tests passed"
   - If failures: "❌ X test(s) failed" with details

## Important Notes

- Always use `--serial` — parallel test runs cause flakiness due to shared DB state
- The test server must be running on port 3001 before tests start
- Tests clear UserDefaults after each run — use `/preview-simulator` afterwards if you need the app connected to the server
- Test output is verbose; focus on the final summary lines

## Troubleshooting

- **"Connection refused"** — test server not running; run `bash OnTrack-iOS/test_server.sh start`
- **Flaky failures** — re-run the specific failing class: `/run-tests CategoryTest`
- **Build fails** — check that Xcode project at `OnTrack-iOS/OnTrack/OnTrack.xcodeproj` exists and compiles
