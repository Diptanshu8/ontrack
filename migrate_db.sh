#!/bin/bash

# Database Migration Script - Raspberry Pi to macOS
# This script automates the database migration process

set -e  # Exit on error

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  OnTrack Database Migration${NC}"
echo -e "${BLUE}  Raspberry Pi → macOS${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Configuration
PI_HOST="djpi"
PI_USER="pi"
PI_PATH="/home/pi/workplace/ontrack_new/ontrack"
DUMP_FILE="raspberry_pi_ontrack.dump"
BACKUP_FILE="mac_backup_$(date +%Y%m%d_%H%M%S).dump"

# Step 1: Check if we can reach the Pi
echo -e "${YELLOW}Step 1: Checking connection to Raspberry Pi...${NC}"
if ssh -o ConnectTimeout=5 ${PI_USER}@${PI_HOST} "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected to ${PI_HOST}${NC}"
else
    echo -e "${RED}✗ Cannot connect to ${PI_HOST}${NC}"
    echo "Please ensure:"
    echo "  1. Raspberry Pi is powered on"
    echo "  2. You can SSH: ssh ${PI_USER}@${PI_HOST}"
    echo "  3. Hostname 'djpi' is correct"
    exit 1
fi
echo ""

# Step 2: Determine database name on Pi
echo -e "${YELLOW}Step 2: Checking database configuration on Pi...${NC}"
DB_NAME=$(ssh ${PI_USER}@${PI_HOST} "cd ${PI_PATH} && grep -A 2 'production:' config/database.yml | grep database | awk '{print \$2}'" 2>/dev/null || echo "")

if [ -z "$DB_NAME" ]; then
    # Try development
    DB_NAME=$(ssh ${PI_USER}@${PI_HOST} "cd ${PI_PATH} && grep -A 2 'development:' config/database.yml | grep database | awk '{print \$2}'" 2>/dev/null || echo "ontrack_development")
fi

echo -e "${GREEN}✓ Database name: ${DB_NAME}${NC}"
echo ""

# Step 3: Create dump on Raspberry Pi
echo -e "${YELLOW}Step 3: Creating database dump on Raspberry Pi...${NC}"
ssh ${PI_USER}@${PI_HOST} "pg_dump -Fc ${DB_NAME} > /tmp/ontrack.dump" 2>&1 | grep -v "NOTICE" || true

# Check dump size
DUMP_SIZE=$(ssh ${PI_USER}@${PI_HOST} "ls -lh /tmp/ontrack.dump | awk '{print \$5}'")
echo -e "${GREEN}✓ Dump created: ${DUMP_SIZE}${NC}"
echo ""

# Step 4: Copy dump to Mac
echo -e "${YELLOW}Step 4: Copying database to Mac...${NC}"
scp -q ${PI_USER}@${PI_HOST}:/tmp/ontrack.dump ./${DUMP_FILE}
echo -e "${GREEN}✓ Database copied: ${DUMP_FILE}${NC}"
echo ""

# Step 5: Backup current Mac database
echo -e "${YELLOW}Step 5: Backing up current Mac database...${NC}"
eval "$(rbenv init -)"
pg_dump -Fc ontrack_development > ${BACKUP_FILE} 2>/dev/null || echo "No existing database to backup"
if [ -f "${BACKUP_FILE}" ]; then
    BACKUP_SIZE=$(ls -lh ${BACKUP_FILE} | awk '{print $5}')
    echo -e "${GREEN}✓ Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})${NC}"
else
    echo -e "${YELLOW}! No backup created (database might be empty)${NC}"
fi
echo ""

# Step 6: Stop Rails server
echo -e "${YELLOW}Step 6: Stopping Rails server...${NC}"
pkill -f "rails s" > /dev/null 2>&1 && echo -e "${GREEN}✓ Rails server stopped${NC}" || echo -e "${YELLOW}! Rails server was not running${NC}"
echo ""

# Step 7: Drop and recreate database
echo -e "${YELLOW}Step 7: Recreating database...${NC}"
bundle exec rake db:drop > /dev/null 2>&1 || true
bundle exec rake db:create > /dev/null 2>&1
echo -e "${GREEN}✓ Database recreated${NC}"
echo ""

# Step 8: Import dump
echo -e "${YELLOW}Step 8: Importing Raspberry Pi database...${NC}"
pg_restore -d ontrack_development -v ${DUMP_FILE} 2>&1 | grep -E "processing|creating|setting" | head -20
echo "..."
echo -e "${GREEN}✓ Database imported${NC}"
echo ""

# Step 9: Verify import
echo -e "${YELLOW}Step 9: Verifying import...${NC}"
cat > /tmp/verify_import.rb << 'EOF'
puts "Users: #{User.count}"
puts "Categories: #{Category.count}"
puts "Expenses: #{Expense.count}"
puts "CSV Configs: #{CsvConfig.count}"
EOF

VERIFICATION=$(bundle exec rails runner /tmp/verify_import.rb 2>/dev/null)
echo -e "${GREEN}✓ Verification:${NC}"
echo "$VERIFICATION" | while read line; do echo "  $line"; done
echo ""

# Step 10: Get Pi database stats for comparison
echo -e "${YELLOW}Step 10: Getting Raspberry Pi database stats for comparison...${NC}"
PI_STATS=$(ssh ${PI_USER}@${PI_HOST} "cd ${PI_PATH} && bundle exec rails runner \"puts 'Users: ' + User.count.to_s; puts 'Categories: ' + Category.count.to_s; puts 'Expenses: ' + Expense.count.to_s; puts 'CSV Configs: ' + CsvConfig.count.to_s\"" 2>/dev/null)

echo -e "${BLUE}Raspberry Pi:${NC}"
echo "$PI_STATS" | while read line; do echo "  $line"; done
echo ""

echo -e "${BLUE}Mac (after import):${NC}"
echo "$VERIFICATION" | while read line; do echo "  $line"; done
echo ""

# Compare
if [ "$VERIFICATION" = "$PI_STATS" ]; then
    echo -e "${GREEN}✓✓✓ DATABASES MATCH! Migration successful! ✓✓✓${NC}"
else
    echo -e "${YELLOW}⚠ Record counts differ - please verify manually${NC}"
fi
echo ""

# Cleanup
echo -e "${YELLOW}Cleanup...${NC}"
ssh ${PI_USER}@${PI_HOST} "rm /tmp/ontrack.dump" > /dev/null 2>&1
rm /tmp/verify_import.rb 2>/dev/null || true
echo -e "${GREEN}✓ Temporary files cleaned${NC}"
echo ""

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo "Summary:"
echo "  - Imported from: ${PI_HOST}:${PI_PATH}"
echo "  - Database: ${DB_NAME}"
echo "  - Dump file: ${DUMP_FILE}"
echo "  - Backup file: ${BACKUP_FILE}"
echo ""
echo "Next steps:"
echo "  1. Start Rails: bundle exec rails s -b 0.0.0.0"
echo "  2. Test login at: http://localhost:3000"
echo "  3. Use your Raspberry Pi credentials"
echo "  4. Run manual tests (see DATABASE_MIGRATION.md)"
echo ""
echo "To revert to backup:"
echo "  bundle exec rake db:drop db:create"
echo "  pg_restore -d ontrack_development ${BACKUP_FILE}"
echo ""


