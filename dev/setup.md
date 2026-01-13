# Project Setup

Never write configuration files by hand. Use tools that know what they're doing.

---

## The Rules

### 1. Never Write tsconfig.json or package.json From Scratch

These files have dozens of options with subtle interactions. You will get them wrong.

**Wrong:**
```bash
touch tsconfig.json
# then manually type 40 lines of config
```

**Right:**
```bash
bun init
# or
bunx create-next-app@latest
# or
bunx create-vite@latest
```

Use a bootstrapping tool. Always.

### 2. Never Edit package.json Directly

Don't open package.json and type in dependencies. The lockfile won't update. Versions will be wrong.

**Wrong:**
```json
{
  "dependencies": {
    "zod": "^3.22.0"  // you typed this by hand
  }
}
```

**Right:**
```bash
bun add zod
```

The package manager handles versions, lockfiles, and peer dependencies. Let it.

### 3. Web Search Before Installing Complex Packages

Some packages have setup steps, CLI tools, or configuration requirements that aren't obvious.

**Before installing these, search first:**
- Prisma
- tRPC
- TanStack Query / Router
- shadcn/ui
- NextAuth / Auth.js
- Tailwind CSS
- ESLint / Prettier configs
- Drizzle ORM
- Turborepo
- Any package with a `init` or `setup` CLI

**Why:** These packages often have:
- Required peer dependencies
- CLI initialization commands
- Config file generation
- Provider/wrapper setup
- Environment variables

Blindly running `bun add prisma` without knowing you also need `bunx prisma init` wastes time.

### 4. Biome for Formatting and Linting

All code must be formatted and linted with Biome. No exceptions.

```bash
bun add -d @biomejs/biome
bunx biome init
```

**Required scripts in package.json:**

```json
{
  "scripts": {
    "format": "biome format --write .",
    "lint": "biome lint .",
    "lint:fix": "biome lint --fix .",
    "check": "biome check --fix ."
  }
}
```

**Must be enforced in CI.** If formatting or linting fails, the build fails.

### 5. Documentation with TypeDoc

All TypeScript code must have TypeDoc-compatible documentation. Docs must compile without errors.

```bash
bun add -d typedoc
```

**Required scripts in package.json:**

```json
{
  "scripts": {
    "docs": "typedoc",
    "docs:watch": "typedoc --watch"
  }
}
```

Create `typedoc.json` configuration:

```json
{
  "entryPoints": ["src/index.ts"],
  "out": "docs",
  "exclude": ["**/*.test.ts", "**/*.e2e.test.ts"],
  "excludePrivate": true,
  "skipErrorChecking": false
}
```

**Must be enforced in CI.** If docs fail to compile, the build fails.

### 6. Testing Setup

Unit tests use **bun test**. E2E tests use **Playwright**.

**File naming conventions:**
- Unit tests: `*.test.ts`
- E2E tests: `*.e2e.test.ts`

**Required scripts in package.json:**

```json
{
  "scripts": {
    "test": "bun test",
    "test:unit": "bun test --test-name-pattern '.*' --preload ./test/setup.ts",
    "test:e2e": "playwright test",
    "test:all": "bun test && playwright test"
  }
}
```

**Playwright setup:**

```bash
bun add -d @playwright/test
bunx playwright install
```

Configure `playwright.config.ts` to match only e2e files:

```typescript
export default defineConfig({
  testMatch: '**/*.e2e.test.ts',
});
```

### 7. CI Must Check Everything

Your CI pipeline must verify:

- [ ] `bun run check` passes (format + lint)
- [ ] `bun run docs` passes (TypeDoc compiles)
- [ ] `bun run test:unit` passes
- [ ] `bun run test:e2e` passes
- [ ] Build succeeds

**Set this up early.** The earlier you have CI enforcing standards, the less cleanup later. A broken build should block merges from day one.

---

## The Process

### New Project

```bash
# 1. Bootstrap with a tool
bunx create-next-app@latest my-app
cd my-app

# 2. Set up Biome immediately
bun add -d @biomejs/biome
bunx biome init
# Add format/lint/check scripts to package.json

# 3. Set up TypeDoc immediately
bun add -d typedoc
# Create typedoc.json config
# Add docs scripts to package.json

# 4. Set up testing immediately
bun add -d @playwright/test
bunx playwright install
# Add test scripts to package.json
# Configure playwright.config.ts for *.e2e.test.ts

# 5. Set up CI
# Add workflow that runs: check, docs, test:unit, test:e2e, build
# Verify the build passes before moving on

# 6. Search for any complex packages you need
# "how to install shadcn ui with bun 2025"

# 7. Follow the official setup
bunx shadcn@latest init

# 8. Add simple packages directly
bun add zod dayjs nanoid
```

**The build must pass at every step.** Don't add features on a broken foundation.

### Adding to Existing Project

```bash
# Simple package - just add it
bun add lodash-es

# Complex package - search first, then follow setup
# Search: "prisma setup bun 2025"
bun add prisma --dev
bun add @prisma/client
bunx prisma init
```

---

## Complex Package Checklist

Before installing a complex package:

- [ ] Search for current setup instructions
- [ ] Check for CLI init commands
- [ ] Note required peer dependencies
- [ ] Check for required config files
- [ ] Look for provider/wrapper requirements
- [ ] Check environment variable requirements

---

## Bootstrap Checklist

When setting up a new project, verify these are in place before writing features:

- [ ] Project bootstrapped with a tool (not manual config)
- [ ] Biome installed and configured
- [ ] Format/lint/check scripts in package.json
- [ ] TypeDoc installed and configured
- [ ] Docs script compiles without errors
- [ ] Bun test configured for `*.test.ts`
- [ ] Playwright configured for `*.e2e.test.ts`
- [ ] Test scripts differentiate unit vs e2e
- [ ] CI pipeline runs check, docs, test:unit, test:e2e, build
- [ ] **Build is passing**

---

## Quick Reference

```bash
# Bootstrap new project
bunx create-next-app@latest
bunx create-vite@latest
bun init

# Add packages
bun add <package>           # dependencies
bun add -d <package>        # devDependencies

# Biome setup
bun add -d @biomejs/biome
bunx biome init

# TypeDoc setup
bun add -d typedoc
# Create typedoc.json

# Testing setup
bun add -d @playwright/test
bunx playwright install

# Run checks
bun run check               # format + lint
bun run docs                # compile docs
bun run test:unit           # unit tests
bun run test:e2e            # e2e tests

# Complex packages - search first, then use their CLI
bunx prisma init
bunx shadcn@latest init
bunx @tanstack/router init
```

Never write config from scratch. Never edit package.json by hand. Search before installing anything complex. Set up linting, docs, and testing early. Keep the build green.

---

## Related

- [Implement Ticket](./implement-ticket.md) - End-to-end process for completing a ticket (uses setup verification)
- [Test-Driven Development](./tdd.md) - TDD workflow for bun test
- [Pre-Push Cleanup](./cleanup.md) - Self-review before pushing
