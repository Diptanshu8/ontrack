#!/bin/bash
# deploy.sh — Deploy OnTrack Rails app to Raspberry Pi production server
# Usage: bash .claude/skills/deploy-pi/deploy.sh
#
# SAFETY CONTRACT:
#   - Never runs db:drop, db:reset, or db:create
#   - Only runs db:migrate (additive, safe to re-run)
#   - Aborts on any failure with rollback instructions

set -euo pipefail

# ── colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${BLUE}▶${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }

# ── config ───────────────────────────────────────────────────────────────────
PI_HOST="pi@djpi"
PI_IP="192.168.1.99"
PI_APP_DIR="/home/pi/workplace/ontrack_new/ontrack"
REMOTE="upstream_ssh"
BRANCH="main"
APP_URL="http://${PI_IP}:3000"

echo ""
log "OnTrack — Raspberry Pi Production Deploy"
echo "  Host  : ${PI_HOST} (${PI_IP})"
echo "  Branch: ${BRANCH}"
echo "  Remote: ${REMOTE}"
echo ""

# ── step 1: verify upstream_ssh remote exists locally ───────────────────────
log "Checking git remote '${REMOTE}'..."
if git remote get-url "${REMOTE}" > /dev/null 2>&1; then
    success "Remote '${REMOTE}' found: $(git remote get-url ${REMOTE})"
else
    error "Remote '${REMOTE}' not found. Add it with:"
    echo "  git remote add ${REMOTE} git@github.com:Diptanshu8/ontrack.git"
    exit 1
fi

# ── step 2: push to GitHub ───────────────────────────────────────────────────
log "Pushing '${BRANCH}' → ${REMOTE}..."
if git push "${REMOTE}" "${BRANCH}"; then
    success "Pushed to ${REMOTE}/${BRANCH}"
else
    error "Push failed. Check SSH key access to GitHub."
    exit 1
fi

echo ""
log "SSHing into ${PI_HOST} to deploy..."
echo ""

# ── steps 3a-g: single SSH session via heredoc ──────────────────────────────
# 'set -e' inside ensures any failure aborts the whole remote block immediately.
ssh "${PI_HOST}" bash << REMOTE_SCRIPT
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "\${BLUE}▶\${NC} \$1"; }
success() { echo -e "\${GREEN}✅ \$1\${NC}"; }
error()   { echo -e "\${RED}❌ \$1\${NC}"; }
warn()    { echo -e "\${YELLOW}⚠️  \$1\${NC}"; }

# 3a — cd to app
log "Changing to app directory..."
cd ${PI_APP_DIR}
success "Working directory: \$(pwd)"

# 3b — init rbenv (required; non-interactive SSH skips .bashrc)
log "Initialising rbenv..."
export PATH="/home/pi/.rbenv/shims:/home/pi/.rbenv/bin:\$PATH"
eval "\$(rbenv init -)"
success "Ruby: \$(ruby --version)"

# 3c — pull latest
log "Pulling ${REMOTE}/${BRANCH}..."
git pull ${REMOTE} ${BRANCH}
success "Git pull complete — \$(git log --oneline -1)"

# 3d — bundle install (clear any stored --without config first)
log "Running bundle install..."
bundle config unset --local without 2>/dev/null || true
bundle install
success "Gems installed"

# 3e — yarn install
log "Running yarn install..."
yarn install
success "JS packages installed"

# 3f — db:migrate ONLY — never drop/reset/create
log "Running db:migrate (RAILS_ENV=production)..."
if bundle exec rake db:migrate; then
    success "Migrations complete"
else
    error "Migration FAILED."
    echo ""
    warn "To rollback the last migration, run:"
    echo "  ssh ${PI_HOST}"
    echo "  cd ${PI_APP_DIR}"
    echo "  eval \"\\\$(rbenv init -)\""
    echo "  bundle exec rake db:rollback"
    echo ""
    warn "DO NOT run db:drop, db:reset, or db:create — they will destroy production data."
    exit 1
fi

# 3g — trigger Puma graceful restart
log "Triggering Puma graceful restart..."
mkdir -p tmp
touch tmp/restart.txt
success "Puma restart triggered (tmp/restart.txt touched)"

echo ""
success "All remote steps complete!"
REMOTE_SCRIPT

REMOTE_EXIT=$?
if [ $REMOTE_EXIT -ne 0 ]; then
    error "Remote deployment failed (exit ${REMOTE_EXIT})."
    exit 1
fi

echo ""

# ── step 4: health check ─────────────────────────────────────────────────────
log "Waiting for Puma to restart..."
sleep 8

log "Checking ${APP_URL}..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${APP_URL}" 2>/dev/null || echo "000")

if [ "${HTTP_CODE}" = "000" ]; then
    warn "Could not reach ${APP_URL} — Puma may still be restarting."
    info "Check manually: ssh ${PI_HOST} 'ps aux | grep puma'"
elif [ "${HTTP_CODE}" = "200" ] || [ "${HTTP_CODE}" = "302" ] || [ "${HTTP_CODE}" = "301" ]; then
    success "Puma is responding (HTTP ${HTTP_CODE})"
else
    warn "Puma returned HTTP ${HTTP_CODE} — may still be starting, check manually."
    info "curl ${APP_URL}"
fi

# ── step 5: success banner ────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
success "Deploy complete!"
echo ""
info "App URL : ${APP_URL}"
info "Alt URL : http://djpi:3000"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
