# E2E Test Troubleshooting

Common issues and solutions when E2E tests fail.

## Debugging Strategy

**Use `console.log()` statements liberally when debugging E2E tests.** Add them throughout your test at key points to understand what's happening:

- Before and after navigation
- Before and after interactions (clicks, typing, etc.)
- When checking element states or visibility
- When verifying data or content
- After waiting for elements or network requests

**Once you identify the root cause, remove all debug `console.log()` statements.** They're temporary debugging aids to help you understand the test flow, not permanent test code.

---

## Poor Targeting: Missing Data Test IDs

### Symptom

```
Error: Element not found: [data-testid=submit-button]
Timeout: 30000ms exceeded while waiting for element
```

### Cause

The element being targeted does not have a `data-testid` attribute attached.

### Solution

**1. Verify the element exists in the component:**

```tsx
// ✗ Bad - no data-testid
<button type="submit">Submit</button>

// ✓ Good - has data-testid
<button data-testid="submit-button" type="submit">
  Submit
</button>
```

**2. Check if the element is conditionally rendered:**

```tsx
// Make sure the element is actually rendered
{
  isVisible && (
    <button data-testid="submit-button" type="submit">
      Submit
    </button>
  );
}
```

**3. Wait for the element to be visible before interacting:**

```typescript
// Wait for element before clicking
const submitButton = page.locator("[data-testid=submit-button]");
await submitButton.waitFor({ state: "visible" });
await submitButton.click();
```

**4. Verify the test ID matches exactly:**

- Check for typos: `submit-button` vs `submit-btn`
- Check for extra spaces or special characters
- Use browser DevTools to inspect the rendered HTML

**5. If the element is in a shadow DOM or iframe:**

```typescript
// For iframes
const frame = page.frameLocator('iframe[name="my-frame"]');
await frame.locator("[data-testid=submit-button]").click();

// For shadow DOM (rare in React/Next.js)
// May need to use different selectors
```

### Prevention

- **Always add `data-testid` when implementing features** — See [E2E Testing - Data Test IDs](./e2e-testing.md#data-test-ids)
- Use consistent naming conventions (kebab-case)
- Add test IDs as part of the initial implementation, not as an afterthought

---

## Button Submits Form Instead of Intended Action

### Symptom

Test clicks a button expecting a specific action, but instead the form submits and navigates away or resets.

```typescript
// Test expects modal to open
await page.click("[data-testid=open-modal-button]");
// But form submits instead, page navigates or resets
```

### Cause

The button is inside a `<form>` element and has `type="submit"` (or defaults to submit), causing form submission instead of the intended action.

### Solution

**1. Change button type to `button`:**

```tsx
// ✗ Bad - submits form
<button data-testid="open-modal-button" type="submit">
  Open Modal
</button>

// ✓ Good - prevents form submission
<button data-testid="open-modal-button" type="button">
  Open Modal
</button>
```

**2. Prevent default behavior in handler:**

```tsx
<button
  data-testid="open-modal-button"
  type="button"
  onClick={(e) => {
    e.preventDefault(); // Extra safety
    openModal();
  }}
>
  Open Modal
</button>
```

**3. Move button outside the form:**

```tsx
// If button shouldn't submit form, move it outside
<form>
  {/* form fields */}
</form>
<button data-testid="open-modal-button" type="button">
  Open Modal
</button>
```

**4. In the test, verify the button type:**

```typescript
// Verify button won't submit form
const button = page.locator("[data-testid=open-modal-button]");
await expect(button).toHaveAttribute("type", "button");
```

### Prevention

- **Always specify `type` attribute** — Use `type="button"` for non-submit actions
- Only use `type="submit"` for actual submit buttons
- Test button behavior in isolation before adding to forms

---

## Server Never Booted Up: Timeout Errors

### Symptom

```
Error: page.goto: Navigation timeout of 30000 ms exceeded
Error: webServer: Timed out waiting for http://localhost:3000
```

### Cause

The development server never started, or Playwright can't connect to it.

### Solution

**1. Check if port is already in use:**

```bash
# Check what's using the port
lsof -i :3000

# If something is using it, kill the process
kill -9 <PID>

# Or use a different port
PORT=3001 bun run dev
```

**2. Try starting the dev server manually:**

```bash
# Start dev server in one terminal
bun run dev

# Wait for it to fully start (check terminal output)
# Then run tests in another terminal
bun run test:e2e
```

**3. Clean build artifacts:**

```bash
# Remove Next.js build cache
rm -rf .next

# Remove node_modules if needed (last resort)
rm -rf node_modules
bun install

# Try again
bun run dev
```

**4. Check Playwright configuration:**

```typescript
// playwright.config.ts
export default defineConfig({
  webServer: {
    command: "bun run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI, // Allows reusing existing server
    timeout: 120000, // Increase timeout if server is slow to start
  },
});
```

**5. Verify environment variables:**

```bash
# Check if required env vars are set
cat .env.local

# Make sure database is initialized
bunx prisma db push
```

**6. Check for errors in dev server:**

```bash
# Run dev server and look for errors
bun run dev

# Common issues:
# - Database connection errors
# - Missing environment variables
# - Port conflicts
# - Build errors
```

**7. Increase timeout in Playwright config:**

never beyond 1 min

```typescript
// If server takes longer to start
webServer: {
  command: 'bun run dev',
  url: 'http://localhost:3000',
  timeout: 6000, // 1 min
  reuseExistingServer: !process.env.CI,
},
```

if its taking longer than a min then something else is going on

### Prevention

- **Always verify dev server starts** before running E2E tests
- Use `reuseExistingServer: !process.env.CI` to allow manual server management
- Keep ports free or use different ports for different projects
- Clean `.next` directory if builds seem corrupted (stop the server first)
- Be careful not to stop servers running on non-dev ports eg the oddball port which for these projects is never 3000 do not stop things on 3000.

---

## Additional Common Issues

### Element Not Visible

**Symptom:** Element exists but test can't interact with it.

**Solutions:**

- Wait for element to be visible: `await element.waitFor({ state: 'visible' })`
- Check if element is behind a modal or overlay
- Verify element isn't hidden with CSS (`display: none`, `visibility: hidden`)
- Check z-index or positioning issues

### Race Conditions

**Symptom:** Tests pass sometimes but fail intermittently.

**Solutions:**

- Wait for network idle: `await page.waitForLoadState('networkidle')`
- Wait for specific elements before proceeding
- Use `fullyParallel: false` and `workers: 1` in Playwright config (already configured)
- Add explicit waits instead of relying on implicit waits

### Authentication State Issues

**Symptom:** Tests fail because user is logged in/out unexpectedly.

**Solutions:**

- Use helper functions to manage auth state: `loginAs()`, `logout()`
- Clear cookies/session between tests if needed
- Use Playwright's `storageState` for consistent auth
- Reset database state if tests modify data

### Flaky Selectors

**Symptom:** Tests break when UI changes slightly.

**Solutions:**

- **Always use `data-testid`** — Never use CSS classes or complex selectors
- Avoid selectors based on text content (unless stable)
- Don't rely on DOM structure (e.g., `:nth-child()`)
- Use stable, semantic test IDs

---

## Debugging Workflow

When E2E tests fail, follow this workflow:

1. **Check the error message** — What exactly failed?
2. **Run dev server manually** — Can you access the app in a browser?
3. **Run tests in headed mode** — See what's happening:
   ```bash
   bunx playwright test --headed
   ```
4. **Run tests with UI** — Interactive debugging:
   ```bash
   bunx playwright test --ui
   ```
5. **Check browser console** — Look for JavaScript errors:
   ```typescript
   page.on("console", (msg) => console.log("Browser:", msg.text()));
   ```
6. **Take a screenshot** — See the state when test fails:
   ```typescript
   await page.screenshot({ path: "screenshots/debug-failure.png" });
   ```
   **Note:** Screenshots should be saved to `screenshots/` folder (see [E2E Testing - Screenshots](./e2e-testing.md#6-take-screenshots-during-tests) for organization guidelines).
7. **Add debug logging liberally** — Use `console.log()` statements throughout your test to understand what's happening:

   ```typescript
   console.log("Current URL:", page.url());
   console.log("Element visible:", await element.isVisible());
   console.log(
     "Element count:",
     await page.locator("[data-testid=item]").count()
   );
   console.log("Page title:", await page.title());
   console.log("Text content:", await element.textContent());
   ```

   **Add console.log statements at key points:**

   - Before and after navigation
   - Before and after clicking elements
   - After waiting for elements
   - When checking element states
   - When verifying data or content

   **Once you identify the root cause, remove all debug console.log statements** — They're temporary debugging aids, not permanent test code.

---

## Quick Reference Checklist

When E2E tests fail, check:

- [ ] Dev server is running (`bun run dev` works)
- [ ] Port is free (`lsof -i :<project-dev-port-number>` shows nothing or expected process)
- [ ] Element has `data-testid` attribute
- [ ] Button has correct `type` attribute (`button` vs `submit`)
- [ ] Element is visible before interaction
- [ ] Network requests completed (`waitForLoadState('networkidle')`)
- [ ] No JavaScript errors in browser console
- [ ] `.next` directory is clean (try `rm -rf .next`)
- [ ] Environment variables are set correctly
- [ ] Database is initialized (`bunx prisma db push`)

---

## Related

- [E2E Testing](./e2e-testing.md) - Main E2E testing strategy and guidelines
- [Implement Ticket](./implement-ticket.md) - E2E preflight check workflow
- [Frontend Architecture](./frontend.md) - Data test ID requirements
