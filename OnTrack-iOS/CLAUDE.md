# iOS Development Rules

This file is automatically loaded by Claude Code when working on iOS files.

## Critical Patterns

### Currency Formatting
- **Spending totals** (large headline amounts): `formattedIndianCurrency` — keeps `.00` decimals
- **Budget, goal, over/under amounts** (secondary line): `formattedIndianCurrencyNoDecimals` — no decimals
- Rule of thumb: if it's "how much you spent", keep decimals; if it's "the budget/goal", drop them

### Swipe Actions
SwiftUI `.swipeActions()` only works on `List` items — **not** `ScrollView > VStack`.
Always use `List > ForEach` when swipe-to-edit or swipe-to-delete is needed.

### Accessibility Identifiers for Tests
UI tests find elements by accessibility identifier, not by type. SwiftUI `List` rows land as `app.otherElements["id"]`, not `app.cells["id"]`. Always use `app.otherElements[...]` when querying List row items in XCUITests.

**NavigationLink rows** have their identifier on the link itself (which is a button), so use `app.buttons["id"]` — not `app.otherElements`.

**Rows with `.swipeActions`**: put `.accessibilityElement(children: .contain)` and `.accessibilityIdentifier` AFTER the `.swipeActions` modifier in the ForEach item chain — the swipe modifier otherwise shadows inner accessibility elements.

**SwiftUI Toggle in Form**: `.accessibilityIdentifier` on a Toggle lands on the Form cell container, not the UISwitch. Tapping `app.switches["id"]` does NOT toggle the value. Instead, tap the toggle's label text: `app.staticTexts["Toggle label text"].firstMatch.tap()`. Confirm by checking that the content controlled by the toggle (e.g. a DatePicker) appeared.

### Server URL
The full URL including path is required: `http://localhost:3001/api/v1`
Not just `http://localhost:3001` — the `/api/v1` suffix is mandatory.

### UserDefaults and Tests
`BaseUITest.swift` uses `-ResetUserDefaults` which clears UserDefaults after every test run. This means `serverBaseURL` is wiped after tests. The `/preview-simulator` skill re-applies it automatically — always use that skill rather than launching manually after tests.

### Amount Storage
Amounts in the API are stored as **integers in cents** (e.g. ₹87,144 = `8714400`). Divide by 100 to get display value. The `APIService` handles this conversion — don't do it manually in views.

## Architecture Notes

- **No Redux/Context** — state lives in `@State` / `@ObservedObject` in views
- **Authentication**: JWT token (90-day expiry), stored in `AuthManager`
- **Category panel**: uses `List` (not `ScrollView`) for swipe action support; `CategorySidePanel` is a separate struct in `FinalDashboardView.swift`
- **FAB (+ button)**: hidden when `showingSidePanel == true` and when not on dashboard tab

## Test Infrastructure

```bash
# Always run serially (parallel causes flakiness)
bash OnTrack-iOS/test.sh --serial

# Single class
bash OnTrack-iOS/test.sh --serial CategoryTest

# Test server (required — app won't connect without it)
bash OnTrack-iOS/test_server.sh start
```

Tests use a cloned copy of the production DB (fetched from djpi via SSH on first run). `DatabaseHelper.swift` provides direct DB access for setup/teardown in tests.
