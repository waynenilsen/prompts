# E2E Testing

End-to-end testing strategy: single serial test suite for faster CI cycles.

---

## Philosophy

**One comprehensive test suite, executed serially, that exercises the entire functionality of the site.**

### Why Serial? Why Single Suite?

Traditional E2E testing often results in hundreds of individual tests that run in parallel. While this provides excellent coverage, it creates problems:

- **Slow CI cycles** — 200+ tests can take 10+ minutes to run
- **Flaky failures** — Parallel execution increases race conditions and resource contention
- **Complex debugging** — Failures scattered across many test files

**Our approach:** A single serial test suite that:

- Exercises all functionality in one run
- Executes steps sequentially (no parallel workers)
- Reuses helper functions to avoid duplication
- Maintains fast cycle times while ensuring comprehensive coverage

---

## Test Organization

### Directory Structure

```
e2e/
├── index.e2e.ts          # Main test suite entry point
├── helpers/
│   ├── auth.ts          # Authentication helpers
│   ├── navigation.ts    # Navigation helpers
│   ├── forms.ts         # Form interaction helpers
│   └── index.ts         # Barrel export
└── flows/
    ├── auth-flow.ts     # Authentication flow
    ├── user-flow.ts     # User management flow
    └── index.ts         # Barrel export
```

### File Size Guidelines

- **Maximum 1000 lines per file** — If a file exceeds this, refactor into separate functions and use barrel exports
- **Helper functions** — Extract reusable actions (clicking, filling forms, navigation) into `e2e/helpers/`
- **Flow functions** — Extract complete user flows into `e2e/flows/`
- **Barrel exports** — Use `index.ts` files to organize exports cleanly

---

## Data Test IDs

**CRITICAL: All interactive elements must have `data-testid` attributes for E2E testing.**

### Requirement

When implementing features, **every element that needs to be interacted with in tests must have a `data-testid` attribute**. This includes:

- Buttons (submit, cancel, action buttons)
- Form inputs (text fields, checkboxes, selects)
- Navigation links and menus
- Interactive components (modals, dropdowns, tabs)
- Any element that needs to be clicked, filled, or verified

### Why Data Test IDs?

- **Stable selectors** — CSS classes and structure change, test IDs don't
- **Clear intent** — Test IDs explicitly mark elements for testing
- **Maintainable** — Tests don't break when styling changes
- **Fast** — Direct ID selection is faster than complex CSS queries

### Implementation

**In your React/Next.js components:**

```typescript
// ✓ Good - elements have data-testid
<button data-testid="submit-button" type="submit">
  Submit
</button>

<input
  data-testid="email-input"
  name="email"
  type="email"
/>

<nav>
  <a data-testid="nav-dashboard" href="/dashboard">Dashboard</a>
  <a data-testid="nav-settings" href="/settings">Settings</a>
</nav>
```

**In your E2E tests:**

```typescript
// ✓ Good - use data-testid selectors
await page.click("[data-testid=submit-button]");
await page.fill("[data-testid=email-input]", "alice@example.com");
await page.click("[data-testid=nav-dashboard]");
```

**NOT:**

```typescript
// ✗ Bad - fragile CSS selectors
await page.click("button.btn-primary");
await page.fill(".email-field input");
await page.click("nav a:first-child");
```

### Naming Convention

Use kebab-case for test IDs, descriptive of the element's purpose:

- `submit-button` (not `btn` or `submitBtn`)
- `email-input` (not `email` or `emailField`)
- `user-menu-dropdown` (not `menu` or `dropdown`)
- `delete-confirm-dialog` (not `dialog` or `confirm`)

---

## Helper Functions

**Reuse code for common tasks.** Don't repeat yourself.

**All helper functions must use `data-testid` selectors.**

### Example: Authentication Helpers

```typescript
// e2e/helpers/auth.ts
import { Page } from "@playwright/test";

export async function loginAs(page: Page, email: string, password: string) {
  await page.goto("/login");
  await page.fill("[data-testid=email-input]", email);
  await page.fill("[data-testid=password-input]", password);
  await page.click("[data-testid=submit-button]");
  await page.waitForURL("/dashboard");
}

export async function logout(page: Page) {
  await page.click("[data-testid=user-menu]");
  await page.click("[data-testid=logout-button]");
  await page.waitForURL("/login");
}

export async function signUp(
  page: Page,
  email: string,
  password: string,
  name: string
) {
  await page.goto("/signup");
  await page.fill("[data-testid=name-input]", name);
  await page.fill("[data-testid=email-input]", email);
  await page.fill("[data-testid=password-input]", password);
  await page.click("[data-testid=submit-button]");
  await page.waitForURL("/dashboard");
}
```

### Example: Navigation Helpers

```typescript
// e2e/helpers/navigation.ts
import { Page } from "@playwright/test";

export async function navigateTo(page: Page, path: string) {
  await page.goto(path);
  await page.waitForLoadState("networkidle");
}

export async function clickNavLink(page: Page, testId: string) {
  await page.click(`[data-testid=${testId}]`);
  await page.waitForLoadState("networkidle");
}

// Example usage:
// await clickNavLink(page, "nav-dashboard");
// await clickNavLink(page, "nav-settings");
```

### Example: Form Helpers

```typescript
// e2e/helpers/forms.ts
import { Page } from "@playwright/test";

export async function fillFormField(page: Page, testId: string, value: string) {
  await page.fill(`[data-testid=${testId}]`, value);
}

export async function submitForm(page: Page) {
  await page.click("[data-testid=submit-button]");
  await page.waitForLoadState("networkidle");
}

// Example usage:
// await fillFormField(page, "email-input", "alice@example.com");
// await fillFormField(page, "password-input", "password123");
// await submitForm(page);
```

### Barrel Export

```typescript
// e2e/helpers/index.ts
export * from "./auth";
export * from "./navigation";
export * from "./forms";
```

---

## Flow Functions

Extract complete user flows into separate files for clarity and reuse.

### Example: Authentication Flow

```typescript
// e2e/flows/auth-flow.ts
import { Page } from "@playwright/test";
import { expect } from "@playwright/test";
import { signUp, loginAs, logout } from "../helpers";

export async function testAuthFlow(page: Page) {
  // Sign up new user
  await signUp(page, "alice@example.com", "password123", "Alice");
  await expect(page).toHaveURL("/dashboard");
  await expect(page.locator("text=Alice")).toBeVisible();

  // Logout
  await logout(page);
  await expect(page).toHaveURL("/login");

  // Login
  await loginAs(page, "alice@example.com", "password123");
  await expect(page).toHaveURL("/dashboard");
}
```

### Barrel Export

```typescript
// e2e/flows/index.ts
export * from "./auth-flow";
export * from "./user-flow";
```

---

## Main Test Suite

The main test file imports flows and executes them serially.

```typescript
// e2e/index.e2e.ts
import { test, expect } from "@playwright/test";
import { testAuthFlow } from "./flows";
import { testUserFlow } from "./flows";

test.describe("E2E Test Suite", () => {
  test("exercises entire application functionality", async ({ page }) => {
    // Authentication flow
    await testAuthFlow(page);

    // User management flow
    await testUserFlow(page);

    // Add more flows as needed...
  });
});
```

**Critical:** This is a single test that exercises everything. Playwright will run it serially.

---

## Playwright Configuration

**Disable parallel execution.** Run tests serially.

```typescript
// playwright.config.ts
import { defineConfig } from "@playwright/test";

const isTty = process.stdout.isTTY;

export default defineConfig({
  testDir: "./e2e",
  testMatch: "**/*.e2e.ts",
  fullyParallel: false, // CRITICAL: Run serially
  workers: 1, // CRITICAL: Single worker for serial execution
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: isTty ? [["html", { open: "never" }]] : [["line"]],
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
  },
  webServer: {
    command: "bun run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
  },
});
```

**Key settings:**

- `fullyParallel: false` — Disables parallel test execution
- `workers: 1` — Ensures single worker (serial execution)

---

## When to Run E2E Tests

### During Implementation

**E2E tests run FIRST** before starting ticket work. This is a preflight check.

```bash
# Preflight check (run first)
bun run test:e2e
```

If E2E tests fail:

- **Fix them before proceeding** — Don't start ticket work on a broken foundation
- **Ralph must fix broken E2E tests** — If running in a Ralph loop, fixing E2E tests becomes the primary task
- **Then proceed** — Once E2E tests pass, continue with ticket implementation

### After Implementation

Run E2E tests again to ensure your changes didn't break anything:

```bash
bun run test:e2e
```

---

## Refactoring Guidelines

### When a File Gets Too Large

If a file exceeds ~1000 lines:

1. **Extract helper functions** — Move reusable code to `e2e/helpers/`
2. **Extract flow functions** — Move complete flows to `e2e/flows/`
3. **Use barrel exports** — Create `index.ts` files for clean imports
4. **Split by domain** — Group related helpers/flows by feature area

### Example Refactoring

**Before (single large file):**

```typescript
// e2e/index.e2e.ts (1500 lines)
test("everything", async ({ page }) => {
  // 500 lines of auth code
  // 500 lines of user management code
  // 500 lines of other flows
});
```

**After (organized):**

```typescript
// e2e/index.e2e.ts (50 lines)
import { testAuthFlow, testUserFlow, testOtherFlow } from "./flows";

test("everything", async ({ page }) => {
  await testAuthFlow(page);
  await testUserFlow(page);
  await testOtherFlow(page);
});

// e2e/flows/auth-flow.ts (200 lines)
// e2e/flows/user-flow.ts (300 lines)
// e2e/flows/other-flow.ts (400 lines)
// e2e/helpers/auth.ts (300 lines)
// e2e/helpers/users.ts (250 lines)
```

---

## Best Practices

### 1. Reuse Helper Functions

**Don't repeat yourself:**

```typescript
// ✗ Bad - repeated code
await page.fill("[name=email]", "alice@example.com");
await page.fill("[name=password]", "password123");
await page.click("button[type=submit]");

// Later in the same file...
await page.fill("[name=email]", "bob@example.com");
await page.fill("[name=password]", "password456");
await page.click("button[type=submit]");
```

**Extract to helper:**

```typescript
// ✓ Good - reusable helper
import { loginAs } from "./helpers";

await loginAs(page, "alice@example.com", "password123");
await loginAs(page, "bob@example.com", "password456");
```

### 2. Use Data Test IDs (Mandatory)

**All interactive elements must have `data-testid` attributes.** This is not optional.

```typescript
// ✗ Bad - fragile CSS selector
await page.click("button.btn-primary");

// ✓ Good - stable test ID (required)
await page.click("[data-testid=submit-button]");
```

**When implementing features, add `data-testid` to all interactive elements:**

- Buttons, links, form inputs
- Navigation elements, menus, dropdowns
- Modals, dialogs, tabs
- Any element that needs to be tested

See [Data Test IDs](#data-test-ids) section above for complete requirements.

### 3. Wait for Network Idle

After navigation or form submission, wait for the page to stabilize:

```typescript
await page.goto("/dashboard");
await page.waitForLoadState("networkidle");
```

### 4. Clear State Between Flows

If flows depend on clean state, reset between them:

```typescript
test("everything", async ({ page }) => {
  await testAuthFlow(page);

  // Reset state if needed
  await page.goto("/reset-test-data");

  await testUserFlow(page);
});
```

### 5. Keep Tests Deterministic

- Use fixed test data (don't rely on random data)
- Clean up after yourself (or use test fixtures)
- Don't depend on external services

---

## File Naming

- **Main test:** `e2e/index.e2e.ts` — Entry point for the test suite
- **Helpers:** `e2e/helpers/*.ts` — Reusable helper functions
- **Flows:** `e2e/flows/*.ts` — Complete user flow functions
- **Barrel exports:** `e2e/helpers/index.ts`, `e2e/flows/index.ts`

**Critical:** Use `*.e2e.ts` extension (NOT `*.e2e.test.ts`). Bun will pick up `.test.ts` files and fail.

---

## Running E2E Tests

```bash
# Run E2E tests
bun run test:e2e

# Run with UI (for debugging)
bunx playwright test --ui

# Run in headed mode (see browser)
bunx playwright test --headed

# Run specific file
bunx playwright test e2e/index.e2e.ts
```

---

## Checklist

Before pushing:

- [ ] E2E tests pass (`bun run test:e2e`)
- [ ] All interactive elements have `data-testid` attributes
- [ ] Helper functions use `data-testid` selectors (not CSS classes)
- [ ] Helper functions are reused (no duplication)
- [ ] Files are under 1000 lines (refactor if needed)
- [ ] Flows are extracted to separate files
- [ ] Barrel exports are used for clean imports
- [ ] Playwright config has `fullyParallel: false` and `workers: 1`

---

## Related

- [E2E Troubleshooting](./e2e-troubleshooting.md) - Common issues and debugging guide
- [Implement Ticket](./implement-ticket.md) - E2E preflight check workflow
- [Unit Testing](./unit-testing.md) - Unit test patterns
- [Frontend Architecture](./frontend.md) - Component testing
- [Project Setup](./setup.md) - Playwright configuration
