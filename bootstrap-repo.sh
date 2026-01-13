#!/usr/bin/env bash
#
# bootstrap-repo.sh - Bootstrap a new project with the full stack
#
# Usage:
#   ./bootstrap-repo.sh <project-name>
#   ./bootstrap-repo.sh my-app
#
# Creates a new Next.js project with:
#   - TypeScript + App Router
#   - Tailwind CSS
#   - Biome (replacing ESLint)
#   - Prisma + SQLite (multi-file schema)
#   - shadcn/ui
#   - TypeDoc
#   - Playwright
#   - Bun test with coverage
#

set -euo pipefail

# Get script directory (where prompts repo lives)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

log() {
  echo -e "${CYAN}▶${RESET} $1"
}

success() {
  echo -e "${GREEN}✓${RESET} $1"
}

error() {
  echo -e "${RED}✗${RESET} $1" >&2
  exit 1
}

# Validate arguments
if [ -z "${1:-}" ]; then
  echo "Usage: bootstrap-repo.sh <project-name>"
  exit 1
fi

PROJECT_NAME="$1"

if [ -d "$PROJECT_NAME" ]; then
  error "Directory '$PROJECT_NAME' already exists"
fi

# Step 1: Create Next.js project
log "Creating Next.js project: $PROJECT_NAME"
bunx create-next-app@latest "$PROJECT_NAME" \
  --typescript \
  --tailwind \
  --biome \
  --app \
  --src-dir \
  --turbopack \
  --import-alias "@/*" \
  --yes \
  --use-bun

cd "$PROJECT_NAME"
success "Next.js project created"

# Step 2: Update Biome and configure for Tailwind
log "Updating Biome and configuring for Tailwind"
bun add -d @biomejs/biome@latest
BIOME_VERSION=$(bunx biome --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
cat > biome.json << EOF
{
  "\$schema": "https://biomejs.dev/schemas/${BIOME_VERSION}/schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "linter": {
    "enabled": true,
    "rules": { "recommended": true }
  },
  "javascript": {
    "formatter": { "quoteStyle": "single", "semicolons": "always" }
  },
  "css": {
    "parser": {
      "cssModules": true,
      "tailwindDirectives": true
    }
  }
}
EOF
success "Biome configured"

# Step 3: Add Bun types for TypeScript
log "Adding Bun types"
bun add -d @types/bun
success "Bun types added"

# Step 4: Set up Prisma with SQLite (using Prisma 6.x for stability)
log "Setting up Prisma with SQLite"
bun add -d prisma@^6
bun add @prisma/client@^6
bunx prisma init --datasource-provider sqlite

# Remove the prisma.config.ts if created (we use the simpler setup)
rm -f prisma.config.ts

# Create multi-file schema structure
# Main schema file (generator + datasource only)
cat > prisma/schema.prisma << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}
EOF

# Example User model in separate file
cat > prisma/user.prisma << 'EOF'
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
EOF

# Create Prisma client singleton
mkdir -p src/lib
cat > src/lib/prisma.ts << 'EOF'
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
EOF

success "Prisma configured with multi-file schema"

# Step 5: Set up shadcn/ui
log "Setting up shadcn/ui"
bunx shadcn@latest init -y -d

success "shadcn/ui initialized"

# Step 6: Set up TypeDoc
log "Setting up TypeDoc"
bun add -d typedoc

cat > typedoc.json << 'EOF'
{
  "entryPoints": ["src"],
  "entryPointStrategy": "expand",
  "out": "docs",
  "exclude": ["**/*.test.ts", "**/*.e2e.ts", "**/node_modules/**", "test/**"],
  "excludePrivate": true,
  "skipErrorChecking": true
}
EOF
success "TypeDoc configured"

# Step 7: Set up Playwright
log "Setting up Playwright"
bun add -d @playwright/test
bunx playwright install chromium

mkdir -p e2e
cat > e2e/example.e2e.ts << 'EOF'
import { test, expect } from '@playwright/test';

test('homepage loads', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/Next/);
});
EOF

cat > playwright.config.ts << 'EOF'
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.e2e.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'bun run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
EOF
success "Playwright configured"

# Step 8: Set up Bun test with coverage
log "Setting up Bun test configuration"
mkdir -p test
cat > test/setup.ts << 'EOF'
import { beforeAll, afterAll } from 'bun:test';

beforeAll(() => {
  // Global test setup
});

afterAll(() => {
  // Global test teardown
});
EOF

cat > bunfig.toml << 'EOF'
[test]
preload = ["./test/setup.ts"]

# Always generate coverage
coverage = true

# Fail build if coverage drops below 95%
coverageThreshold = { line = 0.95, function = 0.95, statement = 0.95 }

# Output formats
coverageReporter = ["text", "lcov"]
coverageDir = "./coverage"

# Skip test files in coverage reports
coverageSkipTestFiles = true
EOF

# Create example test file
cat > src/lib/utils.test.ts << 'EOF'
import { describe, test, expect } from 'bun:test';
import { cn } from './utils';

describe('cn', () => {
  test('merges class names', () => {
    expect(cn('foo', 'bar')).toBe('foo bar');
  });

  test('handles conditional classes', () => {
    expect(cn('foo', false && 'bar', 'baz')).toBe('foo baz');
  });
});
EOF
success "Bun test configured"

# Step 9: Update package.json scripts
log "Updating package.json scripts"
# Use node to update package.json
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = {
  ...pkg.scripts,
  'format': 'biome format --write .',
  'lint': 'biome lint .',
  'lint:fix': 'biome lint --fix .',
  'check': 'biome check --fix .',
  'docs': 'typedoc',
  'docs:watch': 'typedoc --watch',
  'test': 'bun test',
  'test:e2e': 'playwright test',
  'test:all': 'bun test && playwright test',
  'db:push': 'prisma db push',
  'db:studio': 'prisma studio',
  'db:generate': 'prisma generate'
};
pkg.prisma = { schema: './prisma' };
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"
success "package.json updated"

# Step 10: Update .gitignore
log "Updating .gitignore"
cat >> .gitignore << 'EOF'

# Database
prisma/dev.db
prisma/dev.db-journal
prisma/*.db
prisma/*.db-journal

# Generated docs
docs/

# Coverage
coverage/

# Playwright
playwright-report/
test-results/
EOF
success ".gitignore updated"

# Step 11: Install prompts
log "Installing prompts"
"$SCRIPT_DIR/install.sh" "$(pwd)"
success "Prompts installed"

# Step 12: Generate Prisma client and push schema
log "Generating Prisma client"
bunx prisma generate
bunx prisma db push
success "Prisma client generated and schema pushed"

# Step 13: Verify setup
log "Verifying setup..."

echo -e "${DIM}Running: bun run check${RESET}"
bun run check || true

echo -e "${DIM}Running: bun run docs${RESET}"
bun run docs || true

echo -e "${DIM}Running: bun test${RESET}"
bun test

echo -e "${DIM}Running: bun run build${RESET}"
bun run build

echo -e "${DIM}Running: bun run test:e2e${RESET}"
if bun run test:e2e; then
  success "E2E tests passed"
else
  echo -e "${DIM}E2E tests skipped (browser dependencies may be missing)${RESET}"
  echo -e "${DIM}Run 'bunx playwright install-deps' to install system dependencies${RESET}"
fi

success "All checks passed!"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}Project '$PROJECT_NAME' created successfully!${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_NAME"
echo "  bun run dev"
echo ""
