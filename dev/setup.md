# Project Setup

The opinionated stack for zero-configuration deployable applications.

---

## The Stack

| Layer      | Technology                     | Why                                                     |
| ---------- | ------------------------------ | ------------------------------------------------------- |
| Framework  | Next.js                        | Full-stack React, App Router                            |
| API        | tRPC + TanStack Query          | End-to-end type-safe APIs                               |
| Styling    | Tailwind CSS                   | Utility-first, no CSS files to manage                   |
| Components | shadcn/ui                      | Copy-paste components you own                           |
| Database   | Prisma + SQLite                | Type-safe ORM, zero-config database                     |
| Email      | React Email + Mailhog/SendGrid | Beautiful templates, local dev server, production-ready |
| Runtime    | Bun                            | Fast, built-in test runner                              |
| Hosting    | Sprite                         | Zero-config deployment with SQLite persistence          |

### Why This Stack

**SQLite + Sprite** is the key insight. No database server to configure. No connection strings to manage. No external dependencies to provision. Clone, install, run.

> Projects must run immediately on checkout without issue.

This stack achieves that. No `.env` files to copy, no Docker containers to start, no cloud services to configure.

---

## Constraints

### No External Services

**You are forbidden from using external services unless specifically asked.**

Do NOT use:

- Auth0, Clerk, or external auth providers
- Supabase, PlanetScale, or external databases
- Vercel Blob, S3, or external storage
- SendGrid, Resend, or external email
- Stripe (unless payment is explicitly required)

**Why:** External services require configuration, accounts, API keys, and network access. They break the "run on checkout" requirement.

**Instead:**

- Authentication: Roll your own with sessions + Prisma
- Database: SQLite (it's a file)
- Storage: Local filesystem or SQLite blobs
- Email: Log to console in dev, configure only for prod

### GitHub for Everything

Use **GitHub CLI (`gh`)** for all project management:

- Issues for tickets
- Projects for kanban boards
- PRs for code review

Do NOT use Jira, Linear, Notion, or other tools. Keep everything in GitHub.

---

## The Process

### 1. Create Next.js Project

```bash
bunx create-next-app@latest my-app --typescript --tailwind --eslint --app --src-dir
cd my-app
```

Accept defaults. The CLI sets up TypeScript, Tailwind, and App Router correctly.

### 2. Remove ESLint, Add Biome

Next.js ships with ESLint. Replace it with Biome for faster, unified formatting and linting.

```bash
# Remove ESLint
bun remove eslint eslint-config-next
rm .eslintrc.json

# Add Biome
bun add -d @biomejs/biome
bunx biome init
```

Update `biome.json`:

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "organizeImports": { "enabled": true },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "linter": {
    "enabled": true,
    "rules": { "recommended": true }
  },
  "javascript": {
    "formatter": { "quoteStyle": "single", "semicolons": "always" }
  }
}
```

Add scripts to `package.json`:

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

### 3. Set Up Prisma with SQLite (Multi-File Schema)

We use **multi-file Prisma schemas** to organize models by domain. This is GA as of Prisma v6.7.0.

```bash
bun add prisma --dev
bun add @prisma/client
bunx prisma init --datasource-provider sqlite
```

#### Directory Structure

Reorganize into multi-file schema:

```
prisma/
├── schema.prisma       # Generator and datasource only
├── user.prisma         # User model
├── post.prisma         # Post model (example)
├── migrations/         # Auto-generated
└── dev.db              # SQLite database file
```

#### Main Schema File

The `prisma/schema.prisma` contains only generator and datasource:

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = "file:./dev.db"
}
```

#### Model Files

Each domain gets its own `.prisma` file:

```prisma
// prisma/user.prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

```prisma
// prisma/post.prisma
model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
  createdAt DateTime @default(now())
}
```

#### Configure package.json

Tell Prisma to use the directory (required for multi-file):

```json
{
  "prisma": {
    "schema": "./prisma"
  }
}
```

#### Prisma Client Singleton

```typescript
// src/lib/prisma.ts
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
```

#### Generate and Push

```bash
bunx prisma generate
bunx prisma db push
```

#### Add Scripts to package.json

```json
{
  "scripts": {
    "db:push": "prisma db push",
    "db:studio": "prisma studio",
    "db:generate": "prisma generate"
  }
}
```

**Key constraints:**

- `schema.prisma` must be at `prisma/schema.prisma` (not in a subdirectory)
- `migrations/` must be at `prisma/migrations/`
- All `.prisma` files must be in the same `prisma/` directory

### 4. Set Up shadcn/ui

```bash
bunx shadcn@latest init
```

Choose:

- Style: Default
- Base color: Slate (or preference)
- CSS variables: Yes

Add common components:

```bash
bunx shadcn@latest add button card input label
```

Components are copied to `src/components/ui/`. You own them.

### 5. Set Up tRPC

**Critical:** All API calls must use tRPC. Never use Server Actions (except rare cookie writes in auth flows).

```bash
# Install tRPC and dependencies
bun add @trpc/server@latest @trpc/client@latest @trpc/react-query@latest @trpc/next@latest
bun add @tanstack/react-query@latest
bun add superjson
bun add -d @types/superjson
```

Create the tRPC setup files:

```typescript
// src/server/trpc.ts
import { initTRPC } from '@trpc/server';
import superjson from 'superjson';
import { prisma } from '@/lib/prisma';

export function createContext() {
  return { prisma };
}

type Context = Awaited<ReturnType<typeof createContext>>;

const t = initTRPC.context<Context>().create({
  transformer: superjson, // Critical: enables Date/Map/Set serialization
});

export const router = t.router;
export const publicProcedure = t.procedure;
```

```typescript
// src/app/api/trpc/[trpc]/route.ts
import { fetchRequestHandler } from '@trpc/server/adapters/fetch';
import { appRouter } from '@/server/routers/_app';
import { createContext } from '@/server/trpc';

const handler = (req: Request) =>
  fetchRequestHandler({
    endpoint: '/api/trpc',
    req,
    router: appRouter,
    createContext,
  });

export { handler as GET, handler as POST };
```

```typescript
// src/server/routers/_app.ts
import { router } from '@/server/trpc';

export const appRouter = router({});

export type AppRouter = typeof appRouter;
```

```typescript
// src/lib/trpc.ts
import { createTRPCReact } from '@trpc/react-query';
import { httpBatchLink } from '@trpc/client';
import superjson from 'superjson';
import type { AppRouter } from '@/server/routers/_app';

export const trpc = createTRPCReact<AppRouter>();

export const trpcClient = trpc.createClient({
  links: [
    httpBatchLink({
      url: '/api/trpc',
      transformer: superjson,
    }),
  ],
});
```

Update `src/app/layout.tsx` to include providers:

```typescript
// src/app/layout.tsx
'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';
import { trpc, trpcClient } from '@/lib/trpc';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <html>
      <body>
        <trpc.Provider client={trpcClient} queryClient={queryClient}>
          <QueryClientProvider client={queryClient}>
            {children}
          </QueryClientProvider>
        </trpc.Provider>
      </body>
    </html>
  );
}
```

See [tRPC Guide](./trpc.md) for complete patterns and usage.

### 6. Set Up Email (React Email + Mailhog)

Email uses a stage-based abstraction: Mailhog locally, SendGrid in production.

```bash
# Install React Email and dependencies
bun add react-email @react-email/components
bun add -d @types/nodemailer
bun add nodemailer @sendgrid/mail
```

Docker Compose runs Mailhog for local development. Each project gets random ports (50000-60000) to avoid collisions:

```yaml
# docker-compose.yml (ports are generated randomly per project)
services:
  mailhog:
    image: mailhog/mailhog
    ports:
      - "${MAILHOG_SMTP_PORT:-52341}:1025"
      - "${MAILHOG_WEB_PORT:-52342}:8025"
```

The email service abstraction:

```typescript
// src/lib/email.ts
import { render } from "@react-email/components";
import nodemailer from "nodemailer";
import sgMail from "@sendgrid/mail";

const STAGE = process.env.STAGE || "local";

// Configure SendGrid for production
if (STAGE === "production" && process.env.SENDGRID_API_KEY) {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
}

// Mailhog transporter for local development
const mailhogTransport = nodemailer.createTransport({
  host: "localhost",
  port: Number(process.env.MAILHOG_SMTP_PORT) || 1025,
  secure: false,
});

interface SendEmailOptions {
  to: string;
  subject: string;
  template: React.ReactElement;
  from?: string;
}

export async function sendEmail({
  to,
  subject,
  template,
  from,
}: SendEmailOptions) {
  const html = await render(template);
  const defaultFrom = process.env.EMAIL_FROM || "noreply@example.com";

  if (STAGE === "production") {
    await sgMail.send({
      to,
      from: from || defaultFrom,
      subject,
      html,
    });
  } else {
    await mailhogTransport.sendMail({
      to,
      from: from || defaultFrom,
      subject,
      html,
    });
  }
}
```

Create email templates in `src/emails/`:

```typescript
// src/emails/welcome.tsx
import {
  Html,
  Head,
  Body,
  Container,
  Text,
  Button,
} from "@react-email/components";

interface WelcomeEmailProps {
  name: string;
  loginUrl: string;
}

export function WelcomeEmail({ name, loginUrl }: WelcomeEmailProps) {
  return (
    <Html>
      <Head />
      <Body style={{ fontFamily: "sans-serif" }}>
        <Container>
          <Text>Welcome, {name}!</Text>
          <Text>Thanks for signing up. Click below to get started.</Text>
          <Button href={loginUrl}>Log In</Button>
        </Container>
      </Body>
    </Html>
  );
}
```

See [Email](./email.md) for detailed patterns and testing.

### 7. Set Up TypeDoc

```bash
bun add -d typedoc
```

Create `typedoc.json`:

```json
{
  "entryPoints": ["src"],
  "entryPointStrategy": "expand",
  "out": "docs",
  "exclude": ["**/*.test.ts", "**/*.e2e.ts", "**/node_modules/**"],
  "excludePrivate": true,
  "skipErrorChecking": false
}
```

Add scripts:

```json
{
  "scripts": {
    "docs": "typedoc",
    "docs:watch": "typedoc --watch"
  }
}
```

### 8. Set Up Testing

#### Unit Tests (Bun)

Bun has a built-in test runner with coverage. See [Unit Testing](./unit-testing.md) for detailed patterns.

Create test setup with database isolation:

```typescript
// test/setup.ts
import { beforeAll, afterAll } from "bun:test";

beforeAll(() => {
  // Global setup
});

afterAll(() => {
  // Global teardown
});
```

Configure `bunfig.toml` with coverage:

```toml
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
```

Unit tests use `*.test.ts` and live **next to their source files**:

```
src/
├── lib/
│   ├── utils.ts
│   └── utils.test.ts    # Unit test here
├── hooks/
│   ├── use-user.ts
│   └── use-user.test.ts # Unit test here
```

**Key rules:**

- **Do NOT create a `tests/` directory** — tests live next to source
- **One database per test** — enables parallel execution (see [Unit Testing](./unit-testing.md))
- **95% coverage minimum** — enforced by bunfig.toml threshold

#### E2E Tests (Playwright)

```bash
bun add -d @playwright/test
bunx playwright install
```

Create `playwright.config.ts` (must work in non-tty environments out of the box):

```typescript
import { defineConfig } from "@playwright/test";

const isTty = process.stdout.isTTY;

export default defineConfig({
  testDir: "./e2e",
  testMatch: "**/*.e2e.ts", // NOT .e2e.test.ts - bun will pick those up!
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
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

E2E tests live in `e2e/` directory with `*.e2e.ts` extension:

```
e2e/
├── auth.e2e.ts
├── dashboard.e2e.ts
└── users.e2e.ts
```

**Critical:** Do NOT use `.e2e.test.ts` extension. Bun's test runner will pick up anything with `.test.ts` and fail when it can't run Playwright tests.

Add test scripts:

```json
{
  "scripts": {
    "test": "bun test",
    "test:e2e": "playwright test",
    "test:all": "bun test && playwright test"
  }
}
```

### 9. Configure .gitignore

Ensure these are ignored:

```gitignore
# Database
prisma/dev.db
prisma/dev.db-journal

# Generated
.next/
docs/
node_modules/

# Test
playwright-report/
test-results/
```

### 10. Verify Everything Works

```bash
# Format and lint
bun run check

# Generate docs
bun run docs

# Run unit tests
bun test

# Push database schema
bunx prisma db push

# Start dev server
bun run dev

# In another terminal, run E2E tests
bun run test:e2e
```

All commands must pass before writing any feature code.

---

## Sprite Deployment

Sprite provides zero-configuration hosting with SQLite persistence.

### How It Works

1. SQLite database is a file (`prisma/dev.db`)
2. Sprite persists the filesystem
3. No database server to configure
4. Deploy by pushing code

### Deployment Checklist

- [ ] SQLite database works locally
- [ ] No external service dependencies
- [ ] All environment variables have defaults
- [ ] `bun run build` succeeds
- [ ] Application starts with `bun run start`

### Environment Variables

For Sprite, keep configuration minimal:

```typescript
// src/lib/config.ts
export const config = {
  isDev: process.env.NODE_ENV !== "production",
  // Add only what you need, with sensible defaults
};
```

Don't require `.env` files for basic operation.

---

## Final package.json Scripts

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "format": "biome format --write .",
    "lint": "biome lint .",
    "lint:fix": "biome lint --fix .",
    "check": "biome check --fix .",
    "docs": "typedoc",
    "docs:watch": "typedoc --watch",
    "test": "bun test",
    "test:e2e": "playwright test",
    "test:all": "bun test && playwright test",
    "db:push": "prisma db push",
    "db:studio": "prisma studio",
    "db:generate": "prisma generate"
  }
}
```

---

## Bootstrap Checklist

Before writing features, verify:

- [ ] Next.js project created with App Router
- [ ] Biome installed and configured (ESLint removed)
- [ ] Tailwind CSS working
- [ ] Prisma + SQLite configured
- [ ] tRPC + TanStack Query configured (see [tRPC Guide](./trpc.md))
- [ ] shadcn/ui initialized
- [ ] TypeDoc configured
- [ ] Bun test configured with test-near-code pattern
- [ ] Playwright configured for `e2e/*.e2e.ts`
- [ ] All scripts work: `check`, `docs`, `test`, `test:e2e`, `build`
- [ ] Dev server starts without errors
- [ ] **No external services required**
- [ ] **No Server Actions** (except rare cookie writes in auth flows)

---

## Quick Reference

```bash
# Create project
bunx create-next-app@latest my-app --typescript --tailwind --eslint --app --src-dir
cd my-app

# Replace ESLint with Biome
bun remove eslint eslint-config-next && rm .eslintrc.json
bun add -d @biomejs/biome && bunx biome init

# Add Prisma + SQLite
bun add prisma --dev && bun add @prisma/client
bunx prisma init --datasource-provider sqlite
bunx prisma db push

# Add shadcn/ui
bunx shadcn@latest init
bunx shadcn@latest add button card input label

# Add TypeDoc
bun add -d typedoc

# Add Playwright
bun add -d @playwright/test && bunx playwright install

# Verify
bun run check && bun run docs && bun test && bun run build
```

---

## Related

- [Email](./email.md) - React Email templates, Mailhog dev server, SendGrid production
- [Unit Testing](./unit-testing.md) - Database isolation, coverage, parallelism
- [Frontend Architecture](./frontend.md) - Component organization and hooks
- [Test-Driven Development](./tdd.md) - TDD workflow with bun test
- [Implement Ticket](./implement-ticket.md) - Using setup in ticket workflow
- [Engineering Requirements Document](./erd.md) - Technical constraints for projects
