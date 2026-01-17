#!/usr/bin/env bash
# Setup Bun test and Playwright

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Setting up Playwright"
bun add -d @playwright/test
bunx playwright install chromium

mkdir -p e2e/helpers e2e/flows

# Create helper functions
cat > e2e/helpers/homepage.ts << 'EOF'
import { Page, expect } from '@playwright/test';

/**
 * Navigate to the homepage
 */
export async function navigateToHomepage(page: Page) {
  await page.goto('/');
  await page.waitForLoadState('networkidle');
}

/**
 * Fill the name input on the homepage
 */
export async function fillNameInput(page: Page, name: string) {
  await page.fill('[data-testid=name-input]', name);
}

/**
 * Get the greeting text from the homepage
 */
export async function getGreetingText(page: Page): Promise<string> {
  const greeting = page.locator('[data-testid=greeting]');
  await greeting.waitFor({ state: 'visible' });
  return await greeting.textContent() || '';
}

/**
 * Wait for greeting to update (not be "Loading...")
 */
export async function waitForGreetingToLoad(page: Page) {
  const greeting = page.locator('[data-testid=greeting]');
  await expect(greeting).not.toHaveText('Loading...');
}
EOF

cat > e2e/helpers/index.ts << 'EOF'
// Barrel export for helper functions
export * from './homepage';
// Add more helpers as needed (auth, navigation, forms, etc.)
// See @prompts/dev/e2e-testing.md for examples
EOF

# Create flow functions
cat > e2e/flows/homepage-flow.ts << 'EOF'
import { Page, expect } from '@playwright/test';
import {
  navigateToHomepage,
  fillNameInput,
  getGreetingText,
  waitForGreetingToLoad,
} from '../helpers';

/**
 * Test the homepage greeting functionality
 */
export async function testHomepageFlow(page: Page) {
  // Navigate to homepage
  await navigateToHomepage(page);
  await expect(page).toHaveTitle(/Next/);

  // Verify initial state (default name is "World")
  await waitForGreetingToLoad(page);
  const initialGreeting = await getGreetingText(page);
  expect(initialGreeting).toBe('Hello World');

  // Type a new name
  await fillNameInput(page, 'Alice');
  await waitForGreetingToLoad(page);

  // Verify greeting updates
  const updatedGreeting = await getGreetingText(page);
  expect(updatedGreeting).toBe('Hello Alice');

  // Type another name
  await fillNameInput(page, 'Bob');
  await waitForGreetingToLoad(page);

  // Verify greeting updates again
  const finalGreeting = await getGreetingText(page);
  expect(finalGreeting).toBe('Hello Bob');
}
EOF

cat > e2e/flows/index.ts << 'EOF'
// Barrel export for flow functions
export * from './homepage-flow';
// Add more flows as features are implemented
// See @prompts/dev/e2e-testing.md for examples
EOF

# Create main test suite
cat > e2e/index.e2e.ts << 'EOF'
import { test } from '@playwright/test';
import { testHomepageFlow } from './flows';

test.describe('E2E Test Suite', () => {
  test('exercises entire application functionality', async ({ page }) => {
    // Homepage flow - tests greeting functionality
    await testHomepageFlow(page);

    // Add more flows as features are implemented
    // See @prompts/dev/e2e-testing.md for strategy
  });
});
EOF

cat > playwright.config.ts << EOF
import { defineConfig } from '@playwright/test';

const isTty = process.stdout.isTTY;

export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.e2e.ts',
  fullyParallel: false, // CRITICAL: Run serially
  workers: 1, // CRITICAL: Single worker for serial execution
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
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
