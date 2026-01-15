# Frontend Architecture

Component organization, hooks, and UI patterns for Next.js with shadcn/ui.

---

## Philosophy

> "The best code is code that's easy to delete."

Frontend code rots fast. Frameworks change, designs evolve, features get cut. Organize code so pieces can be replaced without excavation.

### Core Principles

1. **Hooks in separate files** — Logic must be testable without rendering
2. **Components are thin** — UI assembly, not business logic
3. **Colocation over convention** — Tests live next to code, not in a `tests/` folder
4. **shadcn/ui as foundation** — Copy-paste components you own, not npm dependencies you don't

---

## Directory Structure

```
src/
├── app/                    # Next.js App Router
│   ├── layout.tsx
│   ├── page.tsx
│   ├── (auth)/
│   │   ├── login/
│   │   │   └── page.tsx
│   │   └── register/
│   │       └── page.tsx
│   └── dashboard/
│       ├── page.tsx
│       └── settings/
│           └── page.tsx
├── components/
│   ├── ui/                 # shadcn/ui components (generated)
│   │   ├── button.tsx
│   │   ├── card.tsx
│   │   └── ...
│   └── [feature]/          # Feature-specific components
│       ├── user-profile.tsx
│       ├── user-profile.test.ts
│       └── ...
├── hooks/
│   ├── use-user.ts
│   ├── use-user.test.ts
│   ├── use-auth.ts
│   ├── use-auth.test.ts
│   └── ...
├── lib/
│   ├── api.ts              # API client
│   ├── api.test.ts
│   ├── utils.ts            # Utilities (cn, formatters, etc.)
│   └── utils.test.ts
└── types/
    └── index.ts            # Shared TypeScript types
```

### Key Rules

- **No `tests/` directory for unit tests** — Tests live next to their source files
- **E2E tests in `e2e/`** — Playwright tests are separate (see [Testing](#testing))
- **Hooks get their own directory** — They're shared across components
- **Feature components are grouped** — `components/users/`, `components/orders/`

---

## Hooks

### Why Separate Files

Hooks contain your business logic. If they're embedded in components:

- You can't test the logic without rendering React
- You can't reuse logic across components
- You can't see the logic at a glance

### The Pattern (with tRPC)

```typescript
// hooks/use-user.ts
import { trpc } from "@/lib/trpc";

export function useUser(userId: string) {
  return trpc.user.getById.useQuery({ id: userId });
}

// For mutations
export function useCreateUser() {
  const utils = trpc.useUtils();

  return trpc.user.create.useMutation({
    onSuccess: () => {
      utils.user.list.invalidate();
    },
  });
}
```

**Note:** With tRPC + TanStack Query, you rarely need custom hooks. Use tRPC hooks directly in components. Only create custom hooks if you need to compose multiple queries or add complex logic.

### Testing Hooks (with tRPC)

```typescript
// hooks/use-user.test.ts
import { renderHook, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { trpc, trpcClient } from "@/lib/trpc";
import { useUser } from "./use-user";

test("useUser fetches user on mount", async () => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });

  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </trpc.Provider>
  );

  const { result } = renderHook(() => useUser("1"), { wrapper });

  await waitFor(() => {
    expect(result.current.isLoading).toBe(false);
  });

  expect(result.current.data).toBeDefined();
});
```

See [tRPC Guide](./trpc.md) for more testing patterns.

### Hook Categories

| Category      | Purpose            | Example                           |
| ------------- | ------------------ | --------------------------------- |
| Data fetching | Load data from API | `useUser`, `useOrders`            |
| Mutations     | Write data to API  | `useCreateUser`, `useUpdateOrder` |
| UI state      | Local UI concerns  | `useModal`, `useToast`            |
| Form state    | Form handling      | `useForm`, `useValidation`        |

---

## Components

### Thin Components

Components should assemble UI, not compute logic.

**Wrong:**

```typescript
// components/user-card.tsx
export function UserCard({ userId }: { userId: string }) {
  const [user, setUser] = useState(null);
  const [orders, setOrders] = useState([]);

  useEffect(() => {
    fetch(`/api/users/${userId}`)
      .then((r) => r.json())
      .then(setUser);
    fetch(`/api/users/${userId}/orders`)
      .then((r) => r.json())
      .then(setOrders);
  }, [userId]);

  const totalSpent = orders.reduce((sum, o) => sum + o.total, 0);
  const isVip = totalSpent > 1000;

  // 50 more lines of logic...
}
```

**Right:**

```typescript
// components/user-card.tsx
import { trpc } from "@/lib/trpc";

export function UserCard({ userId }: { userId: string }) {
  // Multiple focused queries (don't overjoin)
  const { data: user, isLoading: userLoading } = trpc.user.getById.useQuery({
    id: userId,
  });
  const { data: orders } = trpc.order.listByUser.useQuery({ userId });

  // Compute derived state
  const totalSpent = orders?.reduce((sum, o) => sum + o.total, 0) ?? 0;
  const isVip = totalSpent > 1000;

  if (userLoading) return <CardSkeleton />;
  if (!user) return null;

  return (
    <Card>
      <CardHeader>
        <CardTitle>{user.name}</CardTitle>
        {isVip && <Badge>VIP</Badge>}
      </CardHeader>
      <CardContent>
        <p>Total spent: ${totalSpent}</p>
      </CardContent>
    </Card>
  );
}
```

**Key:** Make multiple focused queries instead of overjoining. See [tRPC Guide](./trpc.md) for performance best practices.

### shadcn/ui Usage

shadcn/ui components go in `components/ui/`. They're generated, not written.

```bash
# Add components via CLI
bunx shadcn@latest add button
bunx shadcn@latest add card
bunx shadcn@latest add dialog
```

**Rules:**

- Never modify `components/ui/` files directly (regeneration overwrites)
- Wrap shadcn components if you need custom behavior
- Use the `cn()` utility for conditional classes

```typescript
// components/ui/button.tsx is generated
// components/submit-button.tsx wraps it
import { Button } from "@/components/ui/button";
import { Loader2 } from "lucide-react";

interface SubmitButtonProps {
  isLoading?: boolean;
  children: React.ReactNode;
}

export function SubmitButton({ isLoading, children }: SubmitButtonProps) {
  return (
    <Button type="submit" disabled={isLoading}>
      {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
      {children}
    </Button>
  );
}
```

---

## Testing

### File Naming Convention

| Test Type  | Extension   | Location            | Runner     |
| ---------- | ----------- | ------------------- | ---------- |
| Unit tests | `*.test.ts` | Next to source file | bun test   |
| E2E tests  | `*.e2e.ts`  | `e2e/` directory    | Playwright |

**Critical:** Do NOT use `.e2e.test.ts` for Playwright tests. Bun will pick them up and fail.

### Unit Tests (bun test)

Unit tests live next to their source files:

```
src/
├── hooks/
│   ├── use-user.ts
│   └── use-user.test.ts      # Unit test
├── lib/
│   ├── utils.ts
│   └── utils.test.ts         # Unit test
└── components/
    ├── user-card.tsx
    └── user-card.test.ts     # Unit test
```

```bash
# Run unit tests
bun test
```

### E2E Tests (Playwright)

E2E tests live in a dedicated directory:

```
e2e/
├── auth.e2e.ts
├── dashboard.e2e.ts
└── checkout.e2e.ts
```

```typescript
// e2e/auth.e2e.ts
import { test, expect } from "@playwright/test";

test("user can log in", async ({ page }) => {
  await page.goto("/login");
  await page.fill("[name=email]", "alice@example.com");
  await page.fill("[name=password]", "password123");
  await page.click("button[type=submit]");

  await expect(page).toHaveURL("/dashboard");
});
```

```bash
# Run E2E tests
bunx playwright test
```

### Playwright Configuration

```typescript
// playwright.config.ts
import { defineConfig } from "@playwright/test";

const isTty = process.stdout.isTTY;

export default defineConfig({
  testDir: "./e2e",
  testMatch: "**/*.e2e.ts", // Only .e2e.ts files
  reporter: isTty ? [["html", { open: "never" }]] : [["line"]],
  webServer: {
    command: "bun run dev",
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
```

---

## Auth-Aware Pages

**All pages must respect authentication state.** See [Authentication Guide](./auth.md#conditional-routing-and-redirects) for complete patterns.

### Home Page Pattern

The root path `/` is the application when authenticated, marketing when not:

- **Logged out:** Marketing/landing page
- **Logged in:** Application (dashboard, main view)

**Do NOT put the application under `/app` or `/dashboard`.** The root path is the application.

### Multi-Tenant Routing

**If the application has organizations (multi-tenant):**

The application must be at `/organization-slug` so URLs are shareable. When users copy and paste URLs, they work correctly because the organization context is in the URL path.

**Why:** Users may belong to multiple organizations. URLs must include the organization slug so:

- Shared URLs work correctly (recipient sees the same organization context)
- Users can easily switch between organizations
- URLs are bookmarkable and shareable

**Example:** If a user belongs to "Acme Corp" (slug: `acme-corp`), the application is at `/acme-corp`, not `/`. The root `/` redirects to the user's default organization or shows an organization selector.

### Redirecting Auth Pages

Auth pages (`/sign-in`, `/sign-up`) must redirect if already logged in (to `/` or `/organization-slug` if multi-tenant).

---

## API Integration

### tRPC for All API Calls

**Never use Server Actions.** All API calls must go through tRPC. See [tRPC Guide](./trpc.md) for complete setup.

```typescript
// Use tRPC hooks in components
import { trpc } from "@/lib/trpc";

function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading } = trpc.user.getById.useQuery({ id: userId });
  const createUser = trpc.user.create.useMutation();

  // Component logic...
}
```

### Exception: Cookie Writes (Rare)

The only exception is writing cookies in auth flows. Use POST-redirect-GET pattern:

```typescript
// src/app/api/auth/login/route.ts
// Only for cookie writes in auth flows
export async function POST(request: Request) {
  // ... validate credentials ...
  // ... create session ...
  // Write cookie
  cookies().set('session', sessionId, { ... });
  // Redirect (POST-redirect-GET pattern)
  return NextResponse.redirect(new URL('/dashboard', request.url));
}
```

**Rule:** If you're not writing a cookie in an auth flow, use tRPC.

---

## Checklist

Before adding a new feature:

- [ ] Hooks are in separate files in `hooks/`
- [ ] Components are thin (assembly, not logic)
- [ ] Unit tests are next to source files (`*.test.ts`)
- [ ] E2E tests are in `e2e/` directory (`*.e2e.ts`)
- [ ] shadcn/ui components used where appropriate
- [ ] No business logic in components
- [ ] Types defined in `types/`
- [ ] Pages conditionally render based on auth state (see [Authentication](./auth.md#conditional-routing-and-redirects))
- [ ] Auth pages redirect if already logged in
- [ ] Navigation conditionally shows auth buttons

---

## Related

- [Authentication](./auth.md) - Auth patterns including conditional routing and redirects
- [tRPC](./trpc.md) - End-to-end type-safe APIs with tRPC and TanStack Query
- [Unit Testing](./unit-testing.md) - Database isolation for hook tests, coverage thresholds
- [Project Setup](./setup.md) - Full stack setup including frontend tooling
- [Test-Driven Development](./tdd.md) - TDD workflow for hooks and components
- [Implement Ticket](./implement-ticket.md) - End-to-end ticket workflow
