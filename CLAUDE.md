# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OnTrack is a self-hosted personal budgeting Rails application with a React frontend. The application allows users to track expenses, set spending goals by category, import bank CSV statements, and analyze spending patterns over time. Originally designed for single-user deployment but recently migrated to support multi-user functionality.

## Development Commands

### Setup
```bash
# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
yarn install

# Create and setup database
bundle exec rake db:create
bundle exec rake db:migrate

# Create initial user (run in Rails console)
bundle exec rails c
User.create!(username: "admin", password: "password123")
```

### Running the Application
```bash
# Start Rails server (port 3000)
bundle exec rails server

# Start Webpack dev server (for hot reloading frontend)
bin/webpack-dev-server

# Or run both with:
./bin/dev
```

### Database Operations
```bash
# Run migrations
bundle exec rake db:migrate

# Rollback migration
bundle exec rake db:rollback

# Reset database (WARNING: deletes all data)
bundle exec rake db:reset

# Access Rails console for database queries
bundle exec rails c
```

### Testing
The Rails web app has no automated test suite — manual testing is required.

The iOS app has a full UI test suite. See the iOS App section below for details.

### Code Quality
```bash
# Run ESLint on JavaScript files
npx eslint app/javascript
```

## Architecture

### Technology Stack
- **Backend**: Rails 6.1 (Ruby 3.1.2)
- **Database**: PostgreSQL
- **Frontend**: React 16, Webpack 5, Babel
- **Authentication**: BCrypt + JWT (for mobile API)
- **Server**: Puma

### Directory Structure

```
app/
├── controllers/
│   ├── api/v1/              # RESTful JSON API controllers
│   │   ├── auth_controller.rb
│   │   ├── categories_controller.rb
│   │   ├── expenses_controller.rb
│   │   ├── goals_controller.rb
│   │   └── reports_controller.rb
│   ├── dashboard_controller.rb
│   ├── insights_controller.rb
│   ├── expenses_controller.rb
│   ├── expense_uploads_controller.rb
│   └── sessions_controller.rb
│
├── javascript/
│   ├── components/          # React components organized by feature
│   │   ├── dashboard/
│   │   ├── insights/
│   │   ├── expenses/
│   │   ├── categories/
│   │   ├── goals/
│   │   └── shared/          # Reusable components
│   ├── api/                 # Axios API client modules
│   │   └── modules/
│   ├── helpers/             # Utility functions
│   └── packs/               # Webpack entry points
│
├── models/
│   ├── user.rb
│   ├── expense.rb
│   ├── category.rb
│   ├── csv_config.rb
│   └── concerns/
│       └── paginator.rb
│
├── services/
│   └── csv_processor.rb     # Processes CSV imports
│
└── views/                    # ERB templates for web pages

config/
├── routes.rb                 # Route definitions
├── database.yml              # Database configuration
└── webpack/                  # Webpack configuration

db/
├── migrate/                  # Database migrations
└── schema.rb                 # Current database schema
```

### Data Model

**Core Models:**
- `User`: Authentication and user settings (has many expenses and categories)
- `Expense`: Individual spending records (belongs to category and user)
  - Amount stored as integer (cents)
  - Fields: description, amount, category_id, paid_at, user_id
- `Category`: Spending categories with optional monthly goals (belongs to user)
  - Fields: name, color, monthly_goal, rank (for ordering)
- `CsvConfig`: Reusable CSV parsing configurations for bank imports
  - Stores JSON configuration for column mapping and category matching

### Authentication System

The application supports two authentication methods:

1. **Web Authentication** (cookie-based):
   - Uses signed cookies: `cookies.signed[:user_id]`, `cookies.signed[:logged_in]`
   - Handled by `ApplicationController` and `SessionsController`

2. **API Authentication** (token-based):
   - JWT tokens (HS256 algorithm, 90-day expiry)
   - Used by iOS mobile app
   - Endpoints: `POST /api/v1/auth/login`, `GET /api/v1/auth/validate`

**Password Handling:**
- Passwords hashed with BCrypt
- Recent migration added `login_id` field for authentication lookup
- Legacy `username` encryption still supported

### API Structure

All API endpoints are under `/api/v1` and return JSON. Key endpoints:

**Authentication:**
- `POST /api/v1/auth/login` - Login, returns JWT token
- `GET /api/v1/auth/validate` - Validate JWT token

**Expenses:**
- `GET /api/v1/expenses` - List with filtering (date range, category, search), sorting, pagination
- `POST /api/v1/expenses` - Create single expense
- `POST /api/v1/expenses/bulk_create` - Bulk import expenses
- `PUT /api/v1/expenses/:id` - Update expense
- `DELETE /api/v1/expenses/:id` - Delete expense

**Categories:**
- `GET /api/v1/categories` - List all user categories
- `POST /api/v1/categories` - Create category
- `PUT /api/v1/categories/:id` - Update category
- `DELETE /api/v1/categories/:id` - Delete (fails if expenses exist)

**Reports:**
- `GET /api/v1/reports/year?year=YYYY` - Annual spending breakdown
- `GET /api/v1/reports/month?month=MMMM%20YYYY` - Monthly report with goal progress
- `GET /api/v1/reports/available_years` - Years with expense data

**Goals:**
- `GET /api/v1/goals` - Get monthly goal
- `PUT /api/v1/goals/update` - Update monthly goal

### Frontend Architecture

**Component Organization:**
- Each feature has its own directory under `app/javascript/components/`
- Shared/reusable components in `app/javascript/components/shared/`
- No state management library (Redux/Context) - uses component state
- API calls via Axios modules in `app/javascript/api/modules/`

**Key Components:**
- `Dashboard/Main.jsx` - Current month overview, expense entry
- `Insights/Main.jsx` - Historical analysis (yearly/monthly reports)
- `expenses/FormModal.jsx` - Create/edit expense modal
- `categories/FormModal.jsx` - Category management
- `shared/Modal.jsx` - Base modal wrapper
- `shared/CurrencyInput.jsx` - Formatted money input
- `shared/DatePicker.jsx` - Date selection with react-datepicker

**Webpack Entry Points:**
- `application.js` - Base application JS, loaded on all pages
- `dashboard.jsx` - Dashboard page
- `insights.jsx` - Insights/reports page
- `history.jsx` - Expense history/list page
- `upload_preview.jsx` - CSV import preview

### CSV Import System

The CSV import feature allows flexible parsing of bank statement exports:

1. User uploads CSV file via `ExpenseUploadsController#preview`
2. `CsvProcessor` service processes the CSV using saved `CsvConfig`
3. Preview page shows parsed expenses for review
4. User confirms and bulk creates expenses via `POST /api/v1/expenses/bulk_create`

**CSV Configuration** (`app/models/csv_config.rb`):
- Stores JSON with column mappings, category mappings, filtering rules
- Supports auto-detection based on filename patterns
- Handles various date formats using Chronic gem
- Can normalize description text and map category names

## Common Development Patterns

### Adding a New API Endpoint

1. Add route in `config/routes.rb` under `namespace :api do namespace :v1 do`
2. Create/modify controller in `app/controllers/api/v1/`
3. Inherit from `Api::V1::BaseController` for authentication
4. Return JSON with appropriate status codes
5. Add corresponding API client method in `app/javascript/api/modules/`

### Adding a New React Component

1. Create component file in appropriate directory under `app/javascript/components/`
2. Import and use in parent component or page pack
3. Use `window.API` object to make backend calls (set up in `application.js`)
4. Follow existing patterns for modals, forms, and data fetching

### Database Migrations

1. Generate migration: `bundle exec rails g migration MigrationName`
2. Edit migration file in `db/migrate/`
3. Run migration: `bundle exec rake db:migrate`
4. Schema is auto-updated in `db/schema.rb`

**Important:** Amount fields should be stored as integers (cents, not dollars).

### Working with Money

- Store amounts as integers in cents (e.g., $10.50 = 1050)
- Display amounts formatted via helper functions in `app/javascript/helpers/numerics.js`
- Use `CurrencyInput` component for user input
- API accepts/returns amounts in cents

## Important Notes

- **Multi-User Support**: Recent migrations added `user_id` to expenses and categories, but UI remains single-user focused. When adding features, always scope queries by `current_user`.

- **No Background Jobs**: All processing is synchronous. CSV imports and report generation happen in request/response cycle.

- **Pagination**: Uses offset-based pagination via `Paginator` concern. API accepts `page` and `per_page` parameters.

- **Date Handling**:
  - Backend uses ActiveRecord datetime fields
  - Frontend uses moment.js for formatting and manipulation
  - CSV import uses Chronic gem for flexible date parsing

- **CSRF Protection**: Rails CSRF tokens automatically handled by Axios configuration in `app/javascript/api/modules/base.js`

- **Security**: When working with authentication, never disable CSRF protection. JWT tokens use HS256 with Rails secret key base.

## iOS App (OnTrack-iOS/)

The iOS app is a git submodule at `OnTrack-iOS/OnTrack/`. It is a SwiftUI app that talks to the Rails API.

### Skills (use these instead of manual commands)

| Skill | What it does |
|-------|-------------|
| `/preview-simulator` | Build + install + launch on simulator with server URL configured |
| `/run-tests` | Start test server + run full UI test suite in serial mode |
| `/deploy-ios` | Build + deploy to a physical iPhone |
| `/deploy-pi` | Push main to GitHub + deploy to Raspberry Pi production (migrate, bundle, restart) |

### Running iOS UI Tests Manually
```bash
# Start test server (clones prod DB from djpi via SSH if local DB missing)
bash OnTrack-iOS/test_server.sh start

# Run all tests serially
bash OnTrack-iOS/test.sh --serial

# Run specific test class
bash OnTrack-iOS/test.sh --serial CategoryTest
```

### Simulator Screenshots

After code changes, use `/preview-simulator` — it builds, installs, configures the server URL, and launches in one step.

**Why tests connect but plain launch doesn't:** `BaseUITest.swift` passes `-UITests` launch arg + `UI_TEST_HOST=localhost` / `UI_TEST_PORT=3001` env vars. `NetworkConfiguration.swift` reads these and overrides `serverBaseURL`. A plain launch falls back to UserDefaults — which gets cleared by `-ResetUserDefaults` after each test run. The `/preview-simulator` skill re-applies the server URL after every run.

**Taking screenshots after launching:**
```bash
xcrun simctl io booted screenshot /tmp/screenshot.png
# Always clean up: rm /tmp/screenshot.png
```

### Deploy to Physical iPhone
```bash
# Interactive — lists connected devices and prompts for selection
/deploy-ios
# Or directly:
bash .claude/skills/deploy-ios/deploy.sh "$DEVICE_ID"
```

### Key iOS Files
- **Main view**: `OnTrack-iOS/OnTrack/OnTrack/Views/Dashboard/FinalDashboardView.swift`
- **Login view**: `OnTrack-iOS/OnTrack/OnTrack/Views/Auth/LoginView.swift`
- **API service**: `OnTrack-iOS/OnTrack/OnTrack/Services/APIService.swift`
- **Network config**: `OnTrack-iOS/OnTrack/OnTrack/Utilities/NetworkConfiguration.swift`
- **Assets**: `OnTrack-iOS/OnTrack/OnTrack/Assets.xcassets/` (AppIcon, Logo imagesets)
- **Test base**: `OnTrack-iOS/OnTrack/OnTrackUITests/BaseUITest.swift`
- **Category tests**: `OnTrack-iOS/OnTrack/OnTrackUITests/Flows/CategoryTest.swift`
- **DB helper**: `OnTrack-iOS/OnTrack/OnTrackUITests/Helpers/DatabaseHelper.swift`

## Raspberry Pi Production Server

The production Rails app runs on `pi@djpi` (192.168.1.99) at `/home/pi/workplace/ontrack_new/ontrack`, port 3000. Use `/deploy-pi` to deploy.

Manual equivalent:
```bash
git push upstream_ssh main
ssh pi@djpi "cd /home/pi/workplace/ontrack_new/ontrack && eval \"\$(rbenv init -)\" && git pull upstream_ssh main && bundle install --without development test && yarn install --frozen-lockfile && RAILS_ENV=production bundle exec rake db:migrate && touch tmp/restart.txt"
```

**NEVER run** `db:drop`, `db:reset`, or `db:create` on the Pi — it holds live production data.

---

## Key Files Reference

- **Routes**: `config/routes.rb`
- **Database Schema**: `db/schema.rb`
- **API Base Controller**: `app/controllers/api/v1/base_controller.rb`
- **Web Base Controller**: `app/controllers/application_controller.rb`
- **API Client Setup**: `app/javascript/api/modules/base.js`
- **Main Application JS**: `app/javascript/packs/application.js`
- **Expense Model**: `app/models/expense.rb`
- **Category Model**: `app/models/category.rb`
- **User Model**: `app/models/user.rb`
- **CSV Processor**: `app/services/csv_processor.rb`
