# OnTrack Master Plan

Single source of truth for all open work — bugs, optimizations, features, and tech debt.
Updated: 2026-04-20

---

## 1. Bug Fixes & TODOs

### 1.1 Fix Password Manager Prompt in UI Tests
**Status:** Open
**File:** `OnTrack-iOS/OnTrack/OnTrack/Views/Auth/LoginView.swift`
**Issue:** iOS Password Manager / Save Password prompt triggers during UI tests, blocking automation.
**Root cause:** `.textContentType` modifiers on username/password fields.
**Fix:** Remove or conditionally disable `.textContentType` when `-UITests` launch arg is present.

### 1.2 Revert test.sh Coverage Flag
**Status:** Open
**File:** `OnTrack-iOS/test.sh` line 624
**Issue:** Coverage is enabled for targeted tests (should only be for full suite).
**Fix:** Search for "TODO: Revert this" and disable coverage for targeted runs.

### 1.3 Cache-Then-Network Contract (reference — MUST NOT regress)
**Status:** Implemented, documented
**Invariants:**
1. Views show cached data instantly on initial load (no blank screen when cache exists)
2. Orange 3px bar visible during background network refresh
3. Phase 1 cache read ONLY on initial load, not on pull-to-refresh
4. Phase 2 skipped when import/add-expense overlay is open
5. `fetchWithCache()` in APIService stays network-first — cache reads happen in views
6. All mutations call `CacheService.shared.invalidate(forKey:)` for affected cache keys

### 1.4 Handle Expired JWT (CRITICAL)
**Status:** Not handled
**Issue:** JWT expires after 90 days. When it does, users get silent failures on every API call (401 responses).
**Fix:** In `APIService.makeRequest()`, detect HTTP 401 and:
1. Clear the token via `KeychainManager.shared.deleteToken()`
2. Trigger `AuthManager.shared.logout()` — kicks user back to login screen
3. Show "Session expired — please log in again" message

### 1.5 Expense Delete Confirmation
**Status:** Missing
**Issue:** Swipe-to-delete on expenses is instant — fat-finger risk, no way to undo. Categories have a confirmation alert ("Delete Category?"), expenses don't.
**Fix:** Add confirmation alert on `HistoryView`/`OptimizedHistoryView` swipe-delete, matching the category pattern.

### 1.6 Cache Staleness (No TTL)
**Status:** Known limitation
**Issue:** `CacheService.load()` never expires cached data. If an expense is deleted on the Pi web UI, the iPhone keeps showing it indefinitely until the user triggers a mutation that invalidates the cache.
**Possible fix:** Add a soft TTL (e.g., 24 hours) — cache entries older than TTL are still served instantly but trigger a background refresh even without user action. Or: invalidate all caches on app launch.

---

## 2. Test Suite Improvements

### 2.1 Test Coverage Gaps
**Current:** 82 tests, 0 failures, 1 skip

| Gap | Tests to Add | Effort |
|-----|-------------|--------|
| Invalid login credentials | `testLoginWithInvalidCredentials` — wrong password shows error, stays on login screen | Small |
| Malformed SMS import | `testImportMalformedSMS` — garbage text shows no amount/description parsed | Small |
| Empty clipboard import | `testImportEmptyClipboard` — empty paste shows "No text found" | Small |
| Long string validation | `testCategoryNameMaxLength`, `testExpenseDescriptionMaxLength` | Small |
| Special character handling | `testExpenseWithSpecialChars` — emoji, unicode in description | Small |

### 2.2 Sleep Replacement (Phase 7)
**Status:** Not started
**Estimated savings:** 30-60 seconds per full run
**Targets:**
- `BaseUITest.tapTab()` line 62: replace `sleep(2)` with `waitForExistence` on a known element per tab
- `CategoryTest`: replace `sleep(1)` after menu tap with `waitForExistence` on side panel title
- `ExpenseTest`: replace `sleep(2)` after save with `waitForExistence` on dashboard FAB

### 2.3 Rails Backend Test Suite
**Status:** No automated tests exist
**Risk:** User scoping bugs, API regressions go undetected
**Scope:** Controller-level request specs for critical endpoints:
- `POST /api/v1/auth/login` — valid/invalid credentials
- `GET /api/v1/expenses` — scoped by current_user
- `POST /api/v1/expenses` — creates with correct user_id
- `DELETE /api/v1/expenses/:id` — cannot delete other user's expenses
- `GET /api/v1/categories` — scoped by current_user
- `GET /api/v1/reports/month` — returns correct totals

---

## 3. Refactoring

### 3.1 Split FinalDashboardView.swift (1,315 lines)
**Why:** Every iOS change risks breaking something in this god-file. It contains 7 distinct responsibilities.

**Extract into separate files:**

| New File | Lines | Responsibility |
|----------|-------|---------------|
| `Views/Dashboard/CategorySidePanel.swift` | ~250 | Category list, sort, search, CRUD, swipe actions |
| `Views/Dashboard/NetworkStatusBar.swift` | ~40 | Status line colors + visibility logic |
| `Views/Dashboard/ImportOverlay.swift` | ~50 | Import view presentation + onChange handlers |
| `Views/Dashboard/MonthPickerSheet.swift` | Already exists | Reuse existing |
| `Views/Dashboard/DashboardContent.swift` | ~200 | Pie chart, budget display, month navigation |

`FinalDashboardView.swift` becomes ~400 lines: TabView + shell + state declarations + loadData().

### 3.2 Extract loadData() Pattern
**Why:** 5 views duplicate the same Phase 1 cache / Phase 2 network pattern.
**Approach:** Create a `CachedDataLoader<T>` utility that encapsulates:
- Phase 1: read from CacheService if data is empty
- Phase 2: fetch from network, update state
- RefreshState management
- Error handling

Views call: `loader.load(cacheKey: "expenses") { try await APIService.shared.fetchExpenses() }`

---

## 4. Offline Resilience (continued)

### 4.1 Phase 3.1: Offline Expense Creation — COMPLETE ✅
Implemented: OfflineQueueService, PendingChangesView, auto-sync on foreground, 6 tests in OfflineQueueTest.

### 4.2 Phase 3.2: Offline Edits for All Operations
**Status:** Not started
**Goal:** Queue all write operations offline — edits, deletes, savings, categories, budgets.

**Operation types to queue (11 total):**
- `update_expense`, `delete_expense`
- `create_category`, `update_category`, `delete_category`
- `update_goal` (monthly budget)
- `create_savings_goal`, `update_savings_goal`, `delete_savings_goal`
- `create_contribution`, `delete_contribution`

**Conflict handling:**
- Edit after delete: reject edit
- Delete non-synced create: remove from queue (never reached server)
- Sync order: FIFO (creates before edits, edits before deletes)

**Tests:** 5 new tests (edit offline, delete offline, contribution offline, conflict detection, FIFO sync order)

### 4.3 Phase 4: Retry Logic
**Status:** Not started
**Goal:** Transient GET failures auto-retry before showing error.
- 3 attempts, exponential backoff (1s, 2s, 4s)
- Retryable: `URLError.timedOut`, `.networkConnectionLost`, HTTP 5xx
- NOT retryable: 4xx, `.notConnectedToInternet`
- POST/PUT/DELETE: no auto-retry (handled by offline queue)
- UI: "Connection issue — retrying..." toast during retries

---

## 5. New Features

### 5.1 Settings Tab
**Why:** No way to manage server URL, clear cache, see app state, or configure preferences.
**Currently:** Server URL is buried in login screen. No cache management. No app info.

**Sections:**
| Section | Items |
|---------|-------|
| **Server** | Server URL (editable), connection status indicator, "Test Connection" button |
| **Data** | Clear cache button (with size display), export expenses as CSV |
| **About** | App version, build number, last synced time |
| **Account** | Logged in as (username), Logout button |

**Files:**
- New: `Views/Settings/SettingsView.swift`
- Modify: `FinalDashboardView.swift` — replace 3-dot menu with Settings tab, or add Settings as a tab

**Location:** Inside the 3-dot menu (top-left hamburger), alongside Logout and Pending Changes. No new tab.

### 5.2 Recurring Expenses
**Why:** Monthly rent, subscriptions, insurance premiums are entered manually every month. Automate this.

**Backend (Rails):**
- New table: `recurring_expenses` — user_id, description, amount (cents), category_id, frequency (monthly/weekly/yearly), next_due_date, active (boolean)
- Rake task or background job: `RecurringExpenseProcessor.run` — creates expense entries for due items, advances next_due_date
- API: `GET/POST/PUT/DELETE /api/v1/recurring_expenses`

**iOS:**
- New: `Views/Settings/RecurringExpensesView.swift` — list of recurring items with toggle to enable/disable
- New: `Views/Settings/RecurringExpenseFormView.swift` — create/edit form
- Dashboard indicator: "3 recurring expenses due this month" or auto-created silently

**Tests:** CRUD tests for recurring expenses API + UI test for creating/toggling a recurring expense

### 5.3 Budget Alerts / Notifications
**Why:** User doesn't know they've hit 80% or 100% of monthly budget until they open the app.

**Approach:**
- Local notifications (no push server needed)
- Check budget status on each expense creation
- Thresholds: 80% ("Approaching budget limit"), 100% ("Budget exceeded")
- Settings: toggle alerts on/off, customize threshold percentages

**Files:**
- New: `Services/BudgetAlertService.swift`
- Modify: `AddExpenseView.swift` — after save, check budget and fire notification
- Modify: `SettingsView.swift` — alert preferences

### 5.4 Spending Trends Chart
**Why:** Insights only has single-month and single-year views. No way to see spending trends over time.

**What:** Line chart showing monthly totals for the last 6-12 months. Category breakdown option.

**Approach:**
- Use Swift Charts framework (built into iOS 16+)
- Data: aggregate from existing `fetchMonthlyReport()` for each month
- View: new section in CompleteInsightsView or new tab in the Month/Year segmented control

**Files:**
- New: `Views/Insights/SpendingTrendsView.swift`
- Modify: `CompleteInsightsView.swift` — add "Trends" to segmented control or as a section

### 5.5 CSV Export
**Why:** No way to get data out of the app for spreadsheets, tax reporting, or backup.

**Approach:**
- Generate CSV on-device from cached/fetched expenses
- Share via iOS share sheet (AirDrop, email, Files app)
- Include: date, description, amount, category name
- Accessible from Settings tab

**Files:**
- New: `Services/CSVExportService.swift`
- Modify: `SettingsView.swift` — "Export Expenses" button with date range picker

### 5.6 "Jump to Today" on Dashboard
**Why:** Month picker has "Jump to Today" but dashboard chevrons don't offer a shortcut back to current month. Users have to tap right chevron N times.
**Fix:** Add a small "Today" button next to the month title (only shown when not on current month).

### 5.7 History Pagination
**Why:** `/expenses` API supports `page`/`per_page` but iOS fetches all expenses. Fine for a single user, scales poorly over years.
**Approach:** Infinite scroll in `OptimizedHistoryView` using `fetchExpenses(params: ["page": ...])`. Replaces the current fetch-all pattern.

### 5.8 Dark Mode QA
**Why:** App uses `Color(.systemBackground)` which adapts, but no visual QA pass. Custom category colors (hex strings) may have poor contrast in dark mode.
**Approach:**
- Add screenshot variant in dark mode
- Review custom category color rendering against dark backgrounds
- Consider luminance check when user picks a category color

### 5.9 Localization
**Why:** All UI strings hard-coded in English. Currency display uses ₹ (hardcoded for INR). Not a priority for single-user, but a blocker for sharing.
**Scope:** Extract strings to Localizable.strings. Out of scope for now unless sharing the app.

---

## 9. DevOps & Process

### 9.1 CI Pipeline
**Why:** Tests only run locally via `/run-tests`. No way to catch failures on push. Regressions can slip into main.
**Approach:**
- GitHub Actions workflow on macOS runner (or self-hosted on your Mac to control cost)
- Triggers on push/PR to main
- Runs: `bash OnTrack-iOS/test.sh --serial` + Rails backend tests (once those exist)

### 9.2 Version & Release Discipline
**Why:** `Info.plist` has a version number, but no git tags, no changelog, no way to track what changed between deploys.
**Approach:**
- Bump version in `Info.plist` before each deploy
- Tag the commit: `git tag ios-v1.2.3`
- Maintain `CHANGELOG.md` with user-facing changes

### 9.3 Production Monitoring
**Why:** If the Pi crashes, you discover it when you open the app. No proactive alert.
**Approach:**
- Heartbeat endpoint on Pi (already exists via deploy-pi health check)
- Cron on another machine pings it every 5 minutes
- Alert via email/Slack on failure
- Could also log client-side errors to a file on the Pi

### 9.4 Session-Sharing for CategoryTest, ExpenseTest, SavingsGoalTest
**Why:** Earlier this session, these 3 test classes were kept per-test-login because session sharing broke them. Since then, `fetchWithCache` is stable and cache invalidation on mutations is in place. Session-sharing these could save ~25 login cycles.
**Risk:** Low — network-first `fetchWithCache` means fresh data every time. Cache invalidation on mutations means correct state between tests.
**Verification:** Convert one at a time, run its full class to verify, then commit.

### 9.5 Test Suite Reference Doc Drift
**Why:** `docs/test-suite-reference.md` says 84 tests; actual count is 83 + new `testOrphanedSyncingStateRecovers` = 84 again. Easy to drift.
**Approach:** Update `@test-watcher` to also update the reference doc when test files change. Or add a hook that diffs test count vs doc on every Swift edit.

### 9.6 Additional Offline Queue Tests
**Why:** Our `testOrphanedSyncingStateRecovers` covers the simple case (all items stuck in `.syncing`). Real-world race conditions aren't tested:
- Partial sync success: one op succeeds, then crash, remaining stuck in `.syncing`
- New offline writes arriving while sync is running
- Sync called twice concurrently (we have `isSyncing` flag but no test)

---

## 6. Priority Order

| # | Item | Type | Effort | Impact |
|---|------|------|--------|--------|
| 1 | Test coverage gaps (2.1) | Testing | Small | Catches regressions |
| 2 | Sleep replacement (2.2) | Testing | Small | 30-60s faster runs |
| 3 | Password Manager fix (1.1) | Bug | Small | Eliminates test flakiness |
| 4 | test.sh coverage revert (1.2) | Bug | Tiny | Correctness |
| 5 | **JWT expired handling (1.4)** | Bug | Small | Critical — prevents silent failures |
| 6 | **Expense delete confirmation (1.5)** | Bug | Small | Prevents accidental data loss |
| 7 | "Jump to Today" on Dashboard (5.6) | Feature | Tiny | Obvious UX win |
| 8 | Test suite doc drift fix (9.5) | Process | Tiny | Keeps docs accurate |
| 9 | Settings tab (5.1) | Feature | Medium | User needs this |
| 10 | Session-share 3 test classes (9.4) | Testing | Small | 25 login cycles saved |
| 11 | Additional offline queue tests (9.6) | Testing | Small | Covers race conditions |
| 12 | CSV export (5.5) | Feature | Small | Data portability |
| 13 | Split FinalDashboardView (3.1) | Refactor | Medium | Maintainability |
| 14 | Spending trends chart (5.4) | Feature | Medium | User insight |
| 15 | Cache staleness / TTL (1.6) | Bug | Medium | Multi-device consistency |
| 16 | History pagination (5.7) | Feature | Medium | Scales for large datasets |
| 17 | Recurring expenses (5.2) | Feature | Large | Saves manual work |
| 18 | Offline edits phase 3.2 (4.2) | Feature | Large | Full offline support |
| 19 | Retry logic phase 4 (4.3) | Feature | Medium | Reliability |
| 20 | Budget alerts (5.3) | Feature | Medium | Proactive tracking |
| 21 | Extract loadData pattern (3.2) | Refactor | Medium | Code quality |
| 22 | Rails test suite (2.3) | Testing | Large | Backend safety |
| 23 | CI pipeline (9.1) | Process | Medium | Catches regressions in main |
| 24 | Version/release discipline (9.2) | Process | Small | Change tracking |
| 25 | Production monitoring (9.3) | Process | Medium | Proactive Pi alerts |
| 26 | Dark mode QA (5.8) | Polish | Small | Visual correctness |
| 27 | Localization (5.9) | Polish | Large | Only needed if sharing app |

---

## 7. Status Bar Color Reference

| State | Color | Condition |
|-------|-------|-----------|
| Background refresh | Orange | `RefreshState.shared.isRefreshing` |
| Syncing offline queue | Orange | `offlineQueue.isSyncing` |
| Offline | Red | `!networkStatus.isOnline` |
| Data loaded | Green (3s flash) | `showGreenLine` |

## 8. Critical Files Reference

| Component | Path |
|-----------|------|
| APIService | `OnTrack-iOS/OnTrack/OnTrack/Services/APIService.swift` |
| CacheService | `OnTrack-iOS/OnTrack/OnTrack/Services/CacheService.swift` |
| RefreshState | `OnTrack-iOS/OnTrack/OnTrack/Services/RefreshState.swift` |
| OfflineQueue | `OnTrack-iOS/OnTrack/OnTrack/Services/OfflineQueueService.swift` |
| NetworkConfig | `OnTrack-iOS/OnTrack/OnTrack/Utilities/NetworkConfiguration.swift` |
| Dashboard | `OnTrack-iOS/OnTrack/OnTrack/Views/Dashboard/FinalDashboardView.swift` |
| AddExpense | `OnTrack-iOS/OnTrack/OnTrack/Views/Expenses/AddExpenseView.swift` |
| History | `OnTrack-iOS/OnTrack/OnTrack/Views/History/OptimizedHistoryView.swift` |
| Insights | `OnTrack-iOS/OnTrack/OnTrack/Views/Insights/CompleteInsightsView.swift` |
| Savings List | `OnTrack-iOS/OnTrack/OnTrack/Views/Savings/SavingsGoalsListView.swift` |
| Savings Detail | `OnTrack-iOS/OnTrack/OnTrack/Views/Savings/SavingsGoalDetailView.swift` |
| Test Reference | `docs/test-suite-reference.md` |
| Test Runner | `OnTrack-iOS/test.sh` |
| Test Server | `OnTrack-iOS/test_server.sh` |
