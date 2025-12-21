#!/bin/bash

# OnTrack Database Verification Helper
# Compares a backup file against the live database by restoring it to a temp DB.

set -e

BACKUP_FILE="${1:-}"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <path_to_backup.sql>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Setup environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Initialize rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init - bash)"
fi

export RAILS_ENV=${RAILS_ENV:-development}
TEMP_DB="ontrack_verify_$(date +%s)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 VERIFYING BACKUP: $BACKUP_FILE"
echo "🌍 Environment: $RAILS_ENV"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Get Live Stats
echo "📊 Fetching live database stats..."
LIVE_STATS=$(bundle exec rails runner "puts ({users: User.count, expenses: Expense.count, categories: Category.count}.to_json)" 2>/dev/null)

# 2. Create Temp DB and Restore
echo "🏗️  Creating temporary database: $TEMP_DB"
createdb "$TEMP_DB"

# Ensure we cleanup even if restore fails
trap "echo '🧹 Cleaning up temp database...'; dropdb '$TEMP_DB'" EXIT

echo "📥 Restoring backup into temporary database..."
psql "$TEMP_DB" < "$BACKUP_FILE" > /dev/null 2>&1

# 3. Get Restored Stats
echo "📊 Fetching restored database stats..."
RESTORED_STATS=$(DATABASE_URL=postgres:///$TEMP_DB bundle exec rails runner "puts ({users: User.count, expenses: Expense.count, categories: Category.count}.to_json)" 2>/dev/null)

# 4. Compare
echo ""
echo "📈 COMPARISON RESULTS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "% -15s | % -15s | % -15s | % -10s\n" "Table" "Live DB" "Restored DB" "Status"
printf "% -15s | % -15s | % -15s | % -10s\n" "---------------" "---------------" "---------------" "----------"

tables=("users" "expenses" "categories")
all_match=true

for table in "${tables[@]}"; do
    live_val=$(echo "$LIVE_STATS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('$table', 0))")
    rest_val=$(echo "$RESTORED_STATS" | python3 -c "import sys, json; print(json.load(sys.stdin).get('$table', 0))")
    
    if [ "$live_val" == "$rest_val" ]; then
        status="✅ MATCH"
    else
        status="❌ MISMATCH"
        all_match=false
    fi
    printf "% -15s | % -15s | % -15s | % -10s\n" "$table" "$live_val" "$rest_val" "$status"
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$all_match" = true ]; then
    echo "🎉 Verification Successful! Backup is complete and accurate."
    exit 0
else
    echo "⚠️  Verification Failed! Data counts do not match."
    exit 1
fi
