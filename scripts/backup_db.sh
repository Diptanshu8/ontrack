#!/bin/bash

# OnTrack Database Backup Helper
# Detects the current database based on RAILS_ENV and creates a SQL backup.

set -e

# Setup environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Initialize rbenv if available
export PATH="$HOME/.rbenv/bin:$PATH"
if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init - bash)"
fi

# Set default RAILS_ENV if not set
export RAILS_ENV=${RAILS_ENV:-development}

echo "🔍 Environment: $RAILS_ENV"
echo "🔍 Detecting database name..."

DB_NAME=$(bundle exec rails runner "puts ActiveRecord::Base.connection.current_database" 2>/dev/null || echo "")

if [ -z "$DB_NAME" ]; then
    echo "❌ Error: Could not detect database name. Ensure bundle is installed and DB is accessible."
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="ontrack_backup_${DB_NAME}_${TIMESTAMP}.sql"

echo "📦 Backing up database: $DB_NAME"
echo "📄 Destination: $BACKUP_FILE"

if pg_dump --no-owner --no-privileges "$DB_NAME" > "$BACKUP_FILE"; then
    echo "✅ Backup successful!"
    echo "💡 To verify this backup, run: ./scripts/verify_backup.sh $BACKUP_FILE"
else
    echo "❌ Error: pg_dump failed."
    rm -f "$BACKUP_FILE"
    exit 1
fi
