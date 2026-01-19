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
- **Customize freely, but preserve patterns** — When creating custom components or wrapping shadcn components, you MUST carry over CVA (Class Variance Authority) patterns and other architectural patterns from shadcn

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

**Custom Component Example (with CVA):**

```typescript
// components/feature-button.tsx - Custom component preserving shadcn patterns
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

const featureButtonVariants = cva("base-classes-here", {
  variants: {
    variant: {
      default: "default-variant-classes",
      premium: "premium-variant-classes",
    },
    size: {
      sm: "small-size-classes",
      lg: "large-size-classes",
    },
  },
  defaultVariants: {
    variant: "default",
    size: "sm",
  },
});

interface FeatureButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof featureButtonVariants> {
  // Additional props
}

export function FeatureButton({
  className,
  variant,
  size,
  ...props
}: FeatureButtonProps) {
  return (
    <Button
      className={cn(featureButtonVariants({ variant, size }), className)}
      {...props}
    />
  );
}
```

---

## Styling and Theming

### Semantic Colors Only

**CRITICAL: Retheming is a core requirement. Absolutely NO hardcoded colors.**

All colors must use semantic color tokens from shadcn/ui's CSS variables. These are defined in your `globals.css` and can be changed globally for retheming.

**Wrong:**

```typescript
// ❌ NEVER do this
<div className="bg-blue-500 text-white border-red-600">
  <span style={{ color: "#ff0000" }}>Error</span>
</div>
```

**Right:**

```typescript
// ✅ Use semantic colors
<div className="bg-primary text-primary-foreground border-destructive">
  <span className="text-destructive">Error</span>
</div>
```

### Available Semantic Colors

shadcn/ui provides these semantic color tokens:

- `background` / `foreground` — Base page colors
- `card` / `card-foreground` — Card backgrounds and text
- `popover` / `popover-foreground` — Popover/dropdown colors
- `primary` / `primary-foreground` — Primary actions
- `secondary` / `secondary-foreground` — Secondary actions
- `muted` / `muted-foreground` — Muted/subdued content
- `accent` / `accent-foreground` — Accent highlights
- `destructive` / `destructive-foreground` — Errors, deletions
- `border` — Borders and dividers
- `input` — Input backgrounds
- `ring` — Focus rings

### Adding Custom Semantic Colors

If you need additional semantic colors beyond shadcn's defaults, add them to your `globals.css` CSS variables (for the theme system), then use Tailwind utilities:

```css
/* globals.css - Only define CSS variables here */
@layer base {
  :root {
    /* ... existing shadcn colors ... */

    /* Custom semantic colors */
    --warning: 38 92% 50%;
    --warning-foreground: 48 96% 89%;

    --success: 142 76% 36%;
    --success-foreground: 355 100% 97%;
  }
}
```

```typescript
// ✅ Use Tailwind utilities in components
<div className="bg-warning text-warning-foreground">Warning message</div>
```

**CRITICAL Rules:**

- **NO custom CSS classes** — Use Tailwind utilities only. All styling must be done through Tailwind classes.
- **NO inline styles** — Use Tailwind classes instead of `style={{}}` props.
- **All colors must be semantic tokens** — Never use Tailwind color utilities like `bg-blue-500` or hex codes like `#ff0000` directly in components. Use semantic tokens like `bg-primary`, `bg-destructive`, etc.
- **CSS variables only in `globals.css`** — The only CSS you write is CSS variable definitions in `globals.css` for the theme system. All component styling uses Tailwind.

### Component Customization

You can and should customize shadcn components for your visual needs, but:

1. **Preserve CVA patterns** — Use `class-variance-authority` for variant-based styling
2. **Use semantic colors** — Reference CSS variables, not hardcoded colors
3. **Maintain composability** — Keep the same prop patterns (variant, size, etc.)
4. **Extend, don't replace** — Build on top of shadcn components when possible

```typescript
// ✅ Good: Custom component with CVA and semantic colors (using Tailwind)
import { cva } from "class-variance-authority";
import { cn } from "@/lib/utils";

const statusBadgeVariants = cva(
  "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold",
  {
    variants: {
      status: {
        success: "bg-success text-success-foreground",
        warning: "bg-warning text-warning-foreground",
        error: "bg-destructive text-destructive-foreground",
      },
    },
  }
);
```

**Remember:** All styling uses Tailwind classes. No custom CSS classes, no inline styles. CSS variables in `globals.css` are only for theme definitions.

---

## Testing

### File Naming Convention

| Test Type  | Extension   | Location            | Runner     |
| ---------- | ----------- | ------------------- | ---------- |
| Unit tests | `*.test.ts` | Next to source file | bun test   |
| E2E tests  | `*.e2e.ts`  | `e2e/` directory    | Playwright |

**Critical:** Do NOT use `.e2e.test.ts` for Playwright tests. Bun will pick them up and fail.

### Data Test IDs (Required for E2E)

**All interactive elements must have `data-testid` attributes for E2E testing.**

When implementing features, add `data-testid` to:
- Buttons (submit, cancel, action buttons)
- Form inputs (text fields, checkboxes, selects, textareas)
- Navigation links and menu items
- Interactive components (modals, dropdowns, tabs, accordions)
- Any element that needs to be clicked, filled, or verified in tests

**Example:**

```tsx
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
</nav>
```

**Naming convention:** Use kebab-case, descriptive of the element's purpose:
- `submit-button` (not `btn` or `submitBtn`)
- `email-input` (not `email` or `emailField`)
- `user-menu-dropdown` (not `menu` or `dropdown`)

See [E2E Testing](./e2e-testing.md#data-test-ids) for complete requirements.

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

E2E tests use a **single serial test suite** that exercises the entire application. See [E2E Testing](./e2e-testing.md) for complete strategy.

**Key points:**
- Single test suite executed serially (not parallel)
- Reusable helper functions in `e2e/helpers/`
- Flow functions in `e2e/flows/`
- Files kept under 1000 lines (refactor with barrel exports if needed)

```
e2e/
├── index.e2e.ts          # Main test suite
├── helpers/
│   ├── auth.ts          # Authentication helpers
│   ├── navigation.ts    # Navigation helpers
│   └── index.ts         # Barrel export
└── flows/
    ├── auth-flow.ts     # Authentication flow
    └── index.ts         # Barrel export
```

```bash
# Run E2E tests
bun run test:e2e
```

**See [E2E Testing](./e2e-testing.md) for complete documentation.**

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
- [ ] **NO hardcoded colors** — Only semantic color tokens (e.g., `bg-primary`, `text-destructive`)
- [ ] Custom components preserve CVA patterns and shadcn architectural patterns
- [ ] All colors reference CSS variables for retheming support

---

## Related

- [Authentication](./auth.md) - Auth patterns including conditional routing and redirects
- [tRPC](./trpc.md) - End-to-end type-safe APIs with tRPC and TanStack Query
- [Unit Testing](./unit-testing.md) - Database isolation for hook tests, coverage thresholds
- [Project Setup](./setup.md) - Full stack setup including frontend tooling
- [Test-Driven Development](./tdd.md) - TDD workflow for hooks and components
- [Implement Ticket](./implement-ticket.md) - End-to-end ticket workflow
