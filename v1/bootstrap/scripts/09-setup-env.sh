#!/usr/bin/env bash
# Setup environment files and package.json scripts

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Updating package.json scripts"
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = {
  ...pkg.scripts,
  'dev': 'next dev --port ${DEV_PORT}',
  'format': 'biome format --write .',
  'lint': 'biome lint .',
  'lint:fix': 'biome lint --fix .',
  'check': 'biome check --write --unsafe .',
  'docs': 'typedoc',
  'docs:watch': 'typedoc --watch',
  'test': 'bun test',
  'test:e2e': 'playwright test',
  'test:all': 'bun test && playwright test',
  'db:push': 'prisma db push',
  'db:studio': 'prisma studio',
  'db:generate': 'prisma generate',
  'email:dev': 'email dev --dir src/emails --port 3001',
  'services:up': 'docker compose up -d',
  'services:down': 'docker compose down'
};
pkg.prisma = { schema: './prisma' };
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"

log "Updating .gitignore"
cat >> .gitignore << 'EOF'

# Database
databases/
databases/**/*

# Generated docs
docs/

# Coverage
coverage/

# Playwright
playwright-report/
test-results/
screenshots/

# Environment (keep .env.example, ignore actual .env)
.env
.env.local
.env.*.local
EOF

log "Creating databases directory"
mkdir -p databases

log "Creating .env file"
cat > .env << EOF
# Stage: local | test | production
STAGE=local

# Generated ports (unique per project to avoid collisions)
PORT=${DEV_PORT}
MAILHOG_SMTP_PORT=${MAILHOG_SMTP_PORT}
MAILHOG_WEB_PORT=${MAILHOG_WEB_PORT}

# Email configuration
EMAIL_FROM=noreply@example.com

# SendGrid (production only)
# SENDGRID_API_KEY=SG.xxx

# Database
DATABASE_URL="file:./databases/dev.db"
EOF

# Create .env.example without sensitive values
cat > .env.example << EOF
# Stage: local | test | production
STAGE=local

# Generated ports (unique per project to avoid collisions)
PORT=${DEV_PORT}
MAILHOG_SMTP_PORT=${MAILHOG_SMTP_PORT}
MAILHOG_WEB_PORT=${MAILHOG_WEB_PORT}

# Email configuration
EMAIL_FROM=noreply@example.com

# SendGrid (production only)
# SENDGRID_API_KEY=SG.xxx

# Database
DATABASE_URL="file:./databases/dev.db"
EOF

success "Environment configured"
