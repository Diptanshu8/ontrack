#!/bin/bash

# OnTrack Database Backup Helper
# This script detects the database name and creates a timestamped SQL backup.

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Move to project root so bundle exec works
cd "$PROJECT_ROOT"

# Detect the database name from Rails
echo "🔍 Detecting database name..."
# We try to detect the DB name based on the current environment
DB_NAME=$(bundle exec rails runner "puts ActiveRecord::Base.connection.current_database" 2>/dev/null || echo "")

if [ -z "$DB_NAME" ]; then
    echo "⚠️  Warning: Could not detect database name via Rails."
    echo "   Ensure you are in the correct environment (e.g., RAILS_ENV=production)"
    
    # Try to guess based on standard names if detection failed
    if [ "${RAILS_ENV:-}" == "production" ]; then
        DB_NAME="ontrack_production"
    else
        DB_NAME="ontrack_development"
    fi
    echo "   Guessing DB name: $DB_NAME"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="ontrack_backup_${DB_NAME}_${TIMESTAMP}.sql"

echo "📦 Backing up database: $DB_NAME"
echo "📄 Destination: $BACKUP_FILE"

# Perform the dump
# We add -h localhost to ensure it tries network if socket fails, but usually socket is fine on Pi
if pg_dump --no-owner --no-privileges "$DB_NAME" > "$BACKUP_FILE" 2>/dev/null; then
    echo "✅ Backup successful!"
    echo "💡 To restore this backup later, run:"
    echo "   psql $DB_NAME < $BACKUP_FILE"
else
    echo "❌ Error: pg_dump failed. Does the database '$DB_NAME' exist?"
    rm -f "$BACKUP_FILE"
    exit 1
fi