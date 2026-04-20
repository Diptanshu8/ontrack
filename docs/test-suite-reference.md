# OnTrack iOS UI Test Suite Reference

> **Source of truth** for all iOS UI tests — their purpose, what they validate, and last known status.
> Update this document whenever tests are added, modified, or removed.

**Total test files:** 15 (13 routine + 2 excluded from routine runs)
**Total test methods:** 84 (3 duplicates removed 2026-04-13)
**Last full run:** 2026-04-15 — 82 executed, 0 failures, 1 skip (InsightsTest chevrons conditional)

**Session-sharing optimization (2026-04-13):**
- DashboardFeaturesTest, InsightsTest, HistoryFiltersTest: session-shared (1 login per class)
- CategoryTest, ExpenseTest: per-test login (mutating tests cause race conditions with session sharing)

**Removed duplicate tests (2026-04-13):**
- `DashboardFeaturesTest.testMonthNavigationOnInsights` — covered by `InsightsTest.testInsightsMonthNavigationChevrons`
- `DashboardFeaturesTest.testMonthPickerOnInsights` — covered by `InsightsTest.testInsightsMonthPickerSelectsCorrectMonth`
- `HistoryFiltersTest.testSwipeToDeleteExistingExpenseAndValidateDB` — covered by `ExpenseTest.testSwipeToDeleteSingleExpense`

---

## Test Infrastructure

### BaseUITest.swift
**Path:** `OnTrack-iOS/OnTrack/OnTrackUITests/BaseUITest.swift`

Shared superclass for all test classes.

- **setUpWithError():** Launches app with flags `-UITests`, `-ResetUserDefaults`, `-ResetKeychain`. Sets `UI_TEST_HOST=localhost`, `UI_TEST_PORT=3001`. Logs into DatabaseHelper with "Diptanshu"/"finance".
- **tearDownWithError():** Calls `logoutIfNeeded()` then terminates app.
- **logoutIfNeeded():** Taps menu_button > Logout if menu exists.
- **tapTab(_ label:):** Taps tab by visible label text (required for iOS 26 where identifiers resolve to SF Symbol names).
- **waitFor(_ element:):** Waits for element existence with screenshot on failure.

### DatabaseHelper.swift
**Path:** `OnTrack-iOS/OnTrack/OnTrackUITests/Helpers/DatabaseHelper.swift`

Direct API access for test setup, validation, and cleanup. Authenticates via JWT against the test server at `localhost:3001`.

**Capabilities:**
- Auth: `login(username:password:)`
- Categories: `fetchCategories()`, `fetchCategory(id:)`, `fetchCategory(name:)`, `updateCategory(id:name:goalCents:color:)`, `deleteCategory(id:)`
- Expenses: `fetchExpenses(month:year:)`, `fetchExpense(id:)`, `createExpense(...)`, `deleteExpense(id:)`, `seedCurrentMonthExpenses()`, `fetchExpensesWithFilters(...)`
- Goals: `fetchMonthlyGoal()`, `updateMonthlyGoal(goalRupees:)`
- Savings: `fetchSavingsGoals()`, `fetchSavingsGoal(id:)`, `createSavingsGoal(...)`, `updateSavingsGoal(...)`, `deleteSavingsGoal(id:)`
- Contributions: `fetchContributions(goalId:)`, `createContribution(...)`, `deleteContribution(...)`
- Date/Currency helpers: `getCurrentMonthYear()`, `getMonthName(month:)`, `formatDateForAPI(_:)`, `getCurrentMonthDateRange()`, `getLast90DaysDateRange()`, `getSpecificMonthDateRange(year:month:)`, `formatINR(_:)`

### Page Objects

| Page | Path | Elements |
|------|------|----------|
| **LoginPage** | `Pages/LoginPage.swift` | `usernameField`, `passwordField`, `signInButton`, `login(username:password:)` |
| **ServerSettingsPage** | `Pages/ServerSettingsPage.swift` | `hostField`, `portField`, `saveButton`, `setServer(host:port:)` |

---

## Test Classes

### 1. LoginTest (3 tests)
**Path:** `Flows/LoginTest.swift`
**Scope:** Authentication flow, JWT expiry

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testLoginAndLogout` | Dashboard loads after login (FAB, Insights tab, History tab visible). Month/year display visible. Logout returns to login screen. | - |
| 2 | `testExpiredTokenForcesLogout` | Launches with `-InjectExpiredToken` (DEBUG hook). App attempts dashboard, gets 401, `AuthManager.handleSessionExpiry()` clears token and routes back to login. "Session expired — please log in again." message visible. | - |
| 3 | `testWrongPasswordDoesNotForceLogout` | Regression guard: wrong password on login screen returns 401 but must NOT trigger session-expiry logout. Stays on login with "Invalid username or password" error. Prevents a logout loop. | - |

---

### 2. NavigationTest (1 test)
**Path:** `Flows/NavigationTest.swift`
**Scope:** Tab bar navigation
**Note:** Uses static `hasLoggedIn` flag — logs in once for all tests.

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testNavigateBetweenAllTabs` | Navigates Dashboard > Insights (segmented control exists) > History > Import > Dashboard. Each tab reachable. | - |

---

### 3. CategoryTest (6 tests)
**Path:** `Flows/CategoryTest.swift`
**Scope:** Category CRUD via side panel

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testOpenAndCloseCategorySidePanel` | Side panel opens via hamburger menu. All DB categories visible with names and goals. Scrolling works. Panel closes and FAB returns. | - |
| 2 | `testEditCategoryColor` | Swipe-left > Edit opens edit form. Color picker accessible. Save persists category. | - |
| 3 | `testDeleteCategory` | Creates category via UI, verifies it appears, swipe-left > Delete removes it, confirms deletion in DB. | - |
| 4 | `testCreateCategoryWithColor` | Creates category with name, goal, and color via UI. Validates in side panel. Cleans up via DB. | - |
| 5 | `testSwipeEditCategory` | Swipe-left > Edit opens CategoryEditView with name_field. Delete button NOT present in edit. Cancel without saving. | - |
| 6 | `testDeleteCategoryWithExpenses` | Attempts to delete category that has expenses. Expects "Cannot Delete" error (409). Category persists in UI and DB. | - |

---

### 4. ExpenseTest (3 tests)
**Path:** `Flows/ExpenseTest.swift`
**Scope:** Expense CRUD

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testAddThreeExpenses` | Creates 3 expenses via FAB with description/amount/category. Verifies in History tab. Validates amounts in DB (stored as cents). Deletes all via swipe in History. Confirms deletion in DB. | - |
| 2 | `testSwipeToDeleteSingleExpense` | Creates expense via FAB, navigates to History, finds it, fetches DB ID, swipe-delete, confirms removed from UI and DB. | - |
| 3 | `testAddExpenseViewCoveragePaths` | Opens Add Expense: Save disabled when empty. Fills valid data: Save enabled. Saves, validates in History and DB. Cleans up via search + swipe-delete. | - |

---

### 5. ComprehensiveExpenseTest (3 tests, ordered)
**Path:** `Flows/ComprehensiveExpenseTest.swift`
**Scope:** Multi-expense create/edit/delete flow
**Note:** Shares single app session across all tests (static `hasLoggedIn`/`testApp`). Tests run in order.

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `test1_AddExpensePerCategory` | Adds one expense per category (Groceries, Food outside, Vehicular Expenses). Stores descriptions for subsequent tests. | - |
| 2 | `test2_EditThreeExpenses` | Edits 3 stored expenses in History: changes category on #1, amount to 999 on #2, description on #3. Validates saves. | - |
| 3 | `test3_CleanupTestExpenses` | Deletes all stored test expenses via swipe-delete in History. Clears stored descriptions. | - |

---

### 6. InsightsTest (6 tests)
**Path:** `Flows/InsightsTest.swift`
**Scope:** Insights page (month/year views)

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testInsightsMonthViewShowsSummaryCard` | Month view shows "Total spend" label, budget line, and "Spend by category" header. | - |
| 2 | `testInsightsMonthViewCategoryRowsFormat` | At least one DB category name visible. At least one rupee (Rs) amount in category rows. | - |
| 3 | `testInsightsMonthNavigationChevrons` | Left chevron changes month. Right chevron restores original month. | - |
| 4 | `testInsightsMonthPickerSelectsCorrectMonth` | Taps month label to open picker. Selects first available month. Month label updates. | - |
| 5 | `testInsightsYearViewTableLayout` | Year view has "Category", "Total", "Monthly avg" headers. At least one row with rupee amount. "Total" footer row exists. | - |
| 6 | `testInsightsYearDropdownChangesData` | Year dropdown opens, selects a year. Table headers remain visible after selection. | - |

---

### 7. HistoryFiltersTest (13 tests)
**Path:** `Flows/HistoryFiltersTest.swift`
**Scope:** History tab filtering, search, and deletion

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testDatabaseStateValidation` | Fetches categories/expenses from DB. Counts visible expense cells. Validates consistency. | - |
| 2 | `testFilterByCurrentMonthWithDBValidation` | Seeds expenses if empty. Applies "Current month" filter. Validates UI matches DB. | - |
| 3 | `testFilterByLast90DaysWithDBValidation` | Applies "Last 90 days" filter. Validates UI shows DB-matching expenses. | - |
| 4 | `testFilterBySpecificMonthWithDBValidation` | Targets 2 months ago. Adjusts year/month pickers. Validates UI matches DB for that month. | - |
| 5 | `testFilterByCustomDateRangeWithDBValidation` | Selects "Custom range". Validates date pickers appear. Applies filter. | - |
| 6 | `testFilterSheetLayout` | Filter sheet has "Clear All" at top-left and "Done" at top-right. | - |
| 7 | `testFilterCategoryMultiSelectGridInteractions` | Selects 2 categories via grid. Deselects 1. Applies filter. Reopens and uses "Clear All". | - |
| 8 | `testClearAllFilters` | Applies category filter. "Clear All" clears it. Reopens to confirm no selection. | - |
| 9 | `testEmptyStateForCurrentMonthWhenDBIsEmpty` | If current month has 0 DB expenses, validates empty/minimal UI state. Skips if not empty. | - |
| 10 | `testSwipeToDeleteExistingExpenseAndValidateDB` | Seeds expense via DB. Searches in History. Swipe-deletes. Validates removed from UI and DB. | - |
| 11 | `testSearchByExistingExpenseFromDB` | Picks recent DB expense. Applies date filter if needed. Types description in search. Validates visible. | - |
| 12 | `testFilterByMultipleCategoriesWithDBValidation` | Finds 2 categories with expenses. Selects both in filter. Validates UI shows matching expenses. Clears. | - |
| 13 | `testFilterByCustomDateRangeWithDBValidation` | Applies custom date range filter. Validates filter applied. | - |

---

### 8. ValidationTests (3 tests)
**Path:** `Flows/ValidationTests.swift`
**Scope:** Form validation rules
**Note:** Shares single app session (static `hasLoggedIn`/`testApp`).

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testCategoryFieldsCannotBeEmpty` | Edit category: clearing name disables Save. Clearing goal also disables Save. | - |
| 2 | `testExpenseAmountCannotBeEmptyOrZero` | Add expense: empty amount disables Save. Non-numeric "abc" also disables Save. | - |
| 3 | `testExpenseCategoryCannotBeDefault` | Add expense: no category selected disables Save. Selecting category enables Save. | - |

---

### 9. SavingsGoalTest (16 tests)
**Path:** `Flows/SavingsGoalTest.swift`
**Scope:** Savings goals and contributions (piggy bank feature)

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testNavigateToSavingsTab` | Savings tab reachable. add_goal_button (FAB) exists. | - |
| 2 | `testCreateSavingsGoal` | Creates goal via UI (name + amount). Validates in UI and DB (correct cents conversion). Cleans up. | - |
| 3 | `testAddContributionToGoal` | Creates goal via DB. Adds contribution via UI. Validates in DB with correct cents. Validates linked expense in "Savings" category. Cleans up. | - |
| 4 | `testContributionCreatesExpenseInSavingsCategory` | Adds contribution. Verifies "Savings" category auto-created. Validates linked expense with goal name prefix. Deletes contribution via UI > validates linked expense also deleted. | - |
| 5 | `testDeleteContribution` | Creates goal+contribution via DB. Swipe-deletes contribution in UI. Validates row gone, contribution deleted from DB, linked expense also deleted. | - |
| 6 | `testDeleteSavingsGoal` | Creates goal+contribution via DB. Swipe-deletes goal in UI. Validates goal gone from UI and DB. Validates cascade-deleted linked expense. | - |
| 7 | `testDuplicateGoalNameIsRejected` | Creates goal via DB. Attempts duplicate via UI. Form stays open. Inline error "A goal with this name already exists" shown. Only 1 goal in DB. | - |
| 8 | `testDeletingExpenseFromHistoryRemovesContribution` | Creates goal+contribution via DB. Navigates to History. Searches and swipe-deletes the savings expense. Validates expense gone from DB. Contribution cascade-deleted. Goal currentAmount reset to 0. | - |
| 9 | `testGoalProgressUpdatesAfterContribution` | Creates goal via DB (target Rs 10,000). Adds Rs 5,000 contribution via UI. DB confirms 50% (500,000 cents). UI shows "50%". Savings expense created. | - |
| 10 | `testEditSavingsGoal` | Creates goal via DB. Opens detail > Edit. Changes name and target. Saves. Validates updated title in UI. DB confirms new name and target amount. | - |
| 11 | `testSecondContributionHasCorrectOrdinal` | Creates goal + 1st contribution via DB. Adds 2nd via UI. DB has 2 contributions. 2nd contribution's expense description contains "2nd contribution" and starts with goal name. | - |
| 12 | `testGoalReachedBannerShowsOnCompletion` | Creates goal (target Rs 500). Contributes exactly Rs 500 via UI. "Goal reached!" banner visible. DB confirms currentAmount == targetAmount. | - |
| 13 | `testZeroTargetAmountIsRejected` | Opens add goal form. Enters "0" amount. Save button disabled. No goal created in DB. | - |
| 14 | `testZeroContributionAmountIsRejected` | Opens contribution form. Empty amount: Save disabled. Types "0": Save still disabled. No contribution in DB. | - |
| 15 | `testCreateGoalWithDeadline` | Creates goal with deadline (6 months out) via DB. Opens detail. "by [date]" text visible. | - |
| 16 | `testRemoveDeadlineFromGoal` | Creates goal with deadline via DB. Confirms "by [date]" visible. Removes deadline via API (sends null). Refreshes UI. "by [date]" text gone. | - |

---

### 10. DashboardFeaturesTest (13 tests)
**Path:** `Flows/DashboardFeaturesTest.swift`
**Scope:** Dashboard monthly goal, navigation, month picker, pie chart

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testMonthlyGoalDisplayedOnDashboard` | Fetches monthly goal from DB. "budget" text visible. UI value matches DB. Over/under indicator visible. | - |
| 2 | `testMonthlyGoalDisplayedOnInsights` | Navigates to Insights Month view. "budget" text visible. | - |
| 3 | `testMonthNavigationOnDashboard` | Shows current month. "days left" text visible. Left chevron changes month. "days left" hidden for past month. Right chevron restores. "days left" returns. | - |
| 4 | `testMonthNavigationOnInsights` | Insights Month view. Left chevron changes month. Segmented control persists. Right chevron restores. | - |
| 5 | `testMonthPickerOnDashboard` | Taps month button. "Select Month" title visible. 2+ picker wheels exist. Selects past month. Done button exists. | - |
| 6 | `testMonthPickerWithJumpToToday` | Navigates to past month via chevron. Opens picker. "Jump to Today" button enabled. Taps it + Done. Dashboard shows current month. "days left" visible. | - |
| 7 | `testMonthPickerOnInsights` | Opens month picker from Insights. "Select Month" title visible. "Jump to Today" button exists. Cancels. | - |
| 8 | `testMonthPickerEdgeCases` | Opens picker. Scrolls to earliest year/month, applies. Reopens, scrolls to latest, applies. Dashboard remains stable. | - |
| 9 | `testPieChartSliceTapShowsCategoryPercentage` | Ensures month with expenses selected. Calculates expected percentages from DB. Validates percentage text matches DB values (via legend or tap overlay). Falls back to category name visibility. | - |
| 10 | `testPieChartLegendMatchesSliceCount` | Ensures month with expenses. Groups DB expenses by category. Validates at least one spending category name visible on screen. | - |
| 11 | `testPieChartLegendVisibleOrEmptyState` | Ensures month with expenses. Scrolls to legend area. Validates percentage (%) text visible. If no expenses, checks "No expenses yet" empty state. | - |
| 12 | `testPieChartTapSelection` | Taps center of screen to hit chart. Checks if percentage popup appears. Accepts stable UI as pass. | - |
| 13 | `testEditMonthlyGoalFromDashboard` | Taps edit_monthly_goal_button. "Edit Monthly Goal" modal opens. Clears amount, enters Rs 1,00,000. Saves. DB updated. UI shows "1,00,000" in budget. Restores original goal. | - |

---

### 11. ImportTest (3 tests)
**Path:** `Flows/ImportTest.swift`
**Scope:** SMS/UPI clipboard import flow

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testCancelImportFlow` | Navigates to Import. Pastes HDFC SMS. "Import Expense" overlay appears. Cancel closes overlay. DB count unchanged. | - |
| 2 | `testImportAndSave` | Pastes SMS. Amount auto-filled "3050.00". Description auto-filled. Selects category. Confirms import. DB count +1. Expense found in DB. Visible in History. Cleans up via swipe-delete. | - |
| 3 | `testShortcutTriggerFlow` | Pastes UPI text. Amount auto-filled "500.00". Description auto-filled. Checks auto-categorization. Cancels (no DB change). | - |

---

### 12. OfflineQueueTest (6 tests)
**Path:** `Flows/OfflineQueueTest.swift`
**Scope:** Offline expense queuing and sync
**Note:** Extends XCTestCase directly (not BaseUITest). Uses port 9999 for offline simulation.

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testExpenseSavedOffline` | Logs in online, goes offline. Creates expense via FAB. Form dismisses (queued successfully, no error). | - |
| 2 | `testPendingChangesMenuVisible` | Creates expense offline. Opens menu. pending_changes_button visible. | - |
| 3 | `testPendingChangesViewShowsDetails` | Creates expense offline. Opens pending changes. Expense description visible. "New Expense" type label visible. | - |
| 4 | `testMultipleExpensesQueuedOffline` | Creates 2 expenses offline. Both descriptions visible in pending changes queue. | - |
| 5 | `testOfflineExpenseSyncsOnReconnect` | Creates expense offline. Relaunches online (token persists). Auto-sync completes. DB count +1. Expense found in DB. Cleans up. | - |
| 6 | `testPendingChangesEmptyAfterSync` | Creates expense offline. Relaunches online. After sync: pending changes shows empty/"All changes synced". Expense in DB. | - |
| 7 | `testOrphanedSyncingStateRecovers` | Regression test for stuck `.syncing` ops. Queue expense offline, relaunch with `-InjectOrphanedSyncing` flag (marks pending ops as `.syncing`). Auto-sync must reset them to pending and retry. Verifies DB has the expense. | - |

---

### 13. NetworkResilienceTest (11 tests)
**Path:** `Flows/NetworkResilienceTest.swift`
**Scope:** Offline caching, status indicators, recovery
**Note:** Extends XCTestCase directly. Uses port 9999 for offline simulation.

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testAppShowsErrorWhenServerDown` | Goes offline. Waits 15s. Either Retry button or cached data visible. | - |
| 2 | `testRedStatusLineAppearsWhenOffline` | Goes offline. network_status_line visible (red). offline_status_text contains "Last synced". | - |
| 3 | `testCachedDataShownWhenOffline` | Caches data online. Goes offline. Cached budget (Rs) still visible. | - |
| 4 | `testGreenLineFlashesOnLoad` | Loads online. FAB visible. Checks if network_status_line appeared (green may have faded). | - |
| 5 | `testReconnectionLoadsData` | Goes offline (offline_status_text visible). Relaunches online. Logs in. Dashboard loads. offline_status_text gone. | - |
| 6 | `testAllTabsShowCachedDataOffline` | Visits all tabs online to cache. Goes offline. Each tab (Home, History, Insights, Savings) shows cached data — no "connect"/"wrong" errors. | - |
| 7 | `testRepeatedTabSwitchingOffline` | Caches all tabs. Goes offline. Switches tabs 7+ times. No "connect"/"wrong"/"timed out" errors on any tab. | - |
| 8 | `testEmptyCacheLaunchOffline` | Fresh offline launch: login fails with expected error. Then: cached launch offline shows cached data or "no cached data" message. | - |
| 9 | `testMonthNavigationOffline` | Caches current + previous month online. Goes offline. Current month cached data visible. Back arrow works for cached month. | - |
| 10 | `testFullOfflineFunctionality` | Caches everything (waits for prefetchAll). Goes offline. Validates Dashboard budget, month navigation, History expenses, Insights no-error, Savings list, goal detail — all from cache. | - |
| 11 | `testTimeoutIsFast` | Goes offline. Measures time until resolution. Elapsed < 20s (not 60s default). | - |

---

## Excluded from Routine Runs

These 2 test classes are excluded from `/run-tests` (see memory: project_test_exclusions). Run explicitly when needed.

### 14. ScreenshotTest (1 test)
**Path:** `Flows/ScreenshotTest.swift`
**Scope:** Captures screenshots of every major view for documentation

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testCaptureAllScreens` | Captures 17+ screenshots: login (empty/filled), dashboard, category panel, add expense, history, search, edit expense, insights yearly, insights monthly, savings list, add goal, goal detail, add contribution, edit goal, import tab, overflow menu, server settings. Saves to `/screenshots/`. | - |

### 15. VideoDemoTest (1 test)
**Path:** `Flows/VideoDemoTest.swift`
**Scope:** Deliberate walkthrough for video recording

| # | Test | What it validates | Status |
|---|------|-------------------|--------|
| 1 | `testVideoWalkthrough` | Slow-paced login > dashboard > add expense > history > insights > category panel > add category > logout. Designed for screen recording, not functional testing. | - |

---

## Coverage Summary

| Feature Area | Test Classes | Test Count |
|--------------|-------------|------------|
| Authentication | LoginTest | 3 |
| Navigation | NavigationTest | 1 |
| Categories | CategoryTest | 6 |
| Expenses (basic) | ExpenseTest | 3 |
| Expenses (comprehensive) | ComprehensiveExpenseTest | 3 |
| History/Filters | HistoryFiltersTest | 13 |
| Insights | InsightsTest | 6 |
| Dashboard Features | DashboardFeaturesTest | 13 |
| Import | ImportTest | 3 |
| Validation | ValidationTests | 3 |
| Savings Goals | SavingsGoalTest | 16 |
| Offline Queue | OfflineQueueTest | 6 |
| Network Resilience | NetworkResilienceTest | 11 |
| Screenshots | ScreenshotTest | 1 |
| Video Demo | VideoDemoTest | 1 |
| **Total** | **15 classes** | **87 tests** |

### Areas with Strong Coverage
- Savings goals: 16 tests covering full CRUD, contributions, cascading deletes, validation, deadlines, ordinals, progress tracking
- History filters: 13 tests covering all filter types, search, DB validation, multi-category selection
- Dashboard: 13 tests covering monthly goal, navigation, month picker, pie chart interactions
- Network resilience: 11 tests covering caching, offline status, recovery, tab stability, timeout performance

### Areas with Lighter Coverage
- Login: 1 test (only login/logout flow, no invalid credentials test)
- Navigation: 1 test (happy path only)
- Import: 3 tests (cancel, save, shortcut — no error cases like malformed SMS)
- Validation: 3 tests (category fields, expense amount, expense category — no edge cases like very long strings)
