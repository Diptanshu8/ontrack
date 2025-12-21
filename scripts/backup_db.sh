#!/bin/bash

# OnTrack Database Backup Helper
# This script detects the database name and creates a timestamped SQL backup.

set -e

# Detect the database name from Rails
echo "🔍 Detecting database name..."
DB_NAME=$(bundle exec rails runner "puts ActiveRecord::Base.connection.current_database" 2>/dev/null || echo "ontrack_production")

if [ -z "$DB_NAME" ]; then
    echo "❌ Error: Could not detect database name. Defaulting to ontrack_production."
    DB_NAME="ontrack_production"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="ontrack_backup_${DB_NAME}_${TIMESTAMP}.sql"

echo "📦 Backing up database: $DB_NAME"
echo "📄 Destination: $BACKUP_FILE"

# Perform the dump
# Note: We use --no-owner to make restoration easier across different systems
pg_dump --no-owner --no-privileges "$DB_NAME" > "$BACKUP_FILE"

if [ -s "$BACKUP_FILE" ]; then
    echo "✅ Backup successful!"
    echo "💡 To restore this backup later, run:"
    echo "   psql $DB_NAME < $BACKUP_FILE"
else
    echo "❌ Error: Backup file is empty or was not created."
    exit 1
fi
