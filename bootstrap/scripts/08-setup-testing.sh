#!/usr/bin/env bash
# Setup Bun test and Playwright

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

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

cat > playwright.config.ts << EOF
import { defineConfig } from '@playwright/test';

const isTty = process.stdout.isTTY;

export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.e2e.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: isTty ? [['html', { open: 'never' }]] : [['line']],
  use: {
    baseURL: 'http://localhost:${DEV_PORT}',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'bun run dev',
    url: 'http://localhost:${DEV_PORT}',
    reuseExistingServer: !process.env.CI,
  },
});
EOF

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

success "Testing configured"
