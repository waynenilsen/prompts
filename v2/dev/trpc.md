# tRPC

End-to-end type-safe APIs with tRPC, TanStack Query, and superjson.

---

## Philosophy

> "TypeScript is great, but it only helps you within a single application. tRPC gives you end-to-end type safety across your entire stack."

tRPC provides type-safe APIs without code generation. Types flow from backend to frontend automatically. Combined with TanStack Query, you get powerful data fetching with full type safety.

### Core Principles

1. **End-to-end type safety** — Types flow from backend to frontend automatically
2. **No code generation** — Types are inferred, not generated
3. **TanStack Query integration** — Use React Query hooks for data fetching
4. **superjson for serialization** — Handle Date, Map, Set, and other complex types
5. **Never use Server Actions** — All API calls go through tRPC (except rare cookie writes)

---

## The Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Backend | tRPC | Type-safe API layer |
| Frontend | TanStack Query + tRPC React | Type-safe data fetching |
| Serialization | superjson | Date/Map/Set serialization |
| Runtime | Bun | Fast TypeScript execution |

---

## Installation

### Dependencies

```bash
# Core tRPC
bun add @trpc/server@latest @trpc/client@latest @trpc/react-query@latest @trpc/next@latest

# TanStack Query
bun add @tanstack/react-query@latest

# Serialization
bun add superjson

# Types
bun add -d @types/superjson
```

### Verify Latest Versions

Always use the latest versions. Check for updates:

```bash
bun update @trpc/server @trpc/client @trpc/react-query @trpc/next @tanstack/react-query superjson
```

---

## Setup

### Backend: tRPC Router

Create the tRPC router and context:

```typescript
// src/server/trpc.ts
import { initTRPC } from '@trpc/server';
import superjson from 'superjson';
import { prisma } from '@/lib/prisma';

/**
 * Context for tRPC procedures
 */
export function createContext() {
  return {
    prisma,
    // Add other context (session, user, etc.) as needed
  };
}

type Context = Awaited<ReturnType<typeof createContext>>;

/**
 * Initialize tRPC
 */
const t = initTRPC.context<Context>().create({
  transformer: superjson, // Critical: enables Date/Map/Set serialization
});

export const router = t.router;
export const publicProcedure = t.procedure;
```

### App Router Integration

Create the API route handler:

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

### Root Router

```typescript
// src/server/routers/_app.ts
import { router } from '@/server/trpc';
import { userRouter } from './user';
import { postRouter } from './post';

export const appRouter = router({
  user: userRouter,
  post: postRouter,
});

export type AppRouter = typeof appRouter;
```

### Example Router

```typescript
// src/server/routers/user.ts
import { z } from 'zod';
import { router, publicProcedure } from '@/server/trpc';

export const userRouter = router({
  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      const user = await ctx.prisma.user.findUnique({
        where: { id: input.id },
      });
      return user;
    }),

  create: publicProcedure
    .input(
      z.object({
        email: z.string().email(),
        name: z.string().optional(),
      })
    )
    .mutation(async ({ ctx, input }) => {
      const user = await ctx.prisma.user.create({
        data: input,
      });
      return user;
    }),

  list: publicProcedure
    .input(
      z.object({
        limit: z.number().min(1).max(100).default(10),
        offset: z.number().min(0).default(0),
      })
    )
    .query(async ({ ctx, input }) => {
      const users = await ctx.prisma.user.findMany({
        take: input.limit,
        skip: input.offset,
      });
      return users;
    }),
});
```

### Frontend: tRPC Client

Create the tRPC client with TanStack Query:

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
      transformer: superjson, // Critical: matches backend transformer
    }),
  ],
});
```

### React Query Provider

Wrap your app with providers:

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

---

## Usage Patterns

### Query (Read)

```typescript
// In a component
import { trpc } from '@/lib/trpc';

function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = trpc.user.getById.useQuery({ id: userId });

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!user) return <div>User not found</div>;

  return <div>{user.name}</div>;
}
```

### Mutation (Write)

```typescript
import { trpc } from '@/lib/trpc';
import { useRouter } from 'next/navigation';

function CreateUserForm() {
  const router = useRouter();
  const utils = trpc.useUtils();

  const createUser = trpc.user.create.useMutation({
    onSuccess: () => {
      // Invalidate queries to refetch
      utils.user.list.invalidate();
      router.push('/users');
    },
  });

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    createUser.mutate({
      email: formData.get('email') as string,
      name: formData.get('name') as string,
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="email" type="email" required />
      <input name="name" type="text" />
      <button type="submit" disabled={createUser.isPending}>
        Create User
      </button>
    </form>
  );
}
```

### Multiple Queries

**Don't overjoin.** If you need data about different entities, make multiple requests:

```typescript
// Good: Multiple focused queries
function UserDashboard({ userId }: { userId: string }) {
  const { data: user } = trpc.user.getById.useQuery({ id: userId });
  const { data: posts } = trpc.post.listByUser.useQuery({ userId });
  const { data: orders } = trpc.order.listByUser.useQuery({ userId });

  // Each query is focused and cacheable independently
}

// Bad: Overjoining in backend
// Don't do this:
// trpc.user.getWithEverything.useQuery({ id: userId })
// Returns: { user, posts, orders, comments, likes, ... }
```

**Why multiple queries:**
- Better caching (invalidate posts without invalidating user)
- Parallel fetching (TanStack Query batches automatically)
- Clearer data dependencies
- Easier to reason about

### Denormalization (Rare)

Only denormalize when:
- Performance is critical
- Data changes infrequently
- Query is a bottleneck

```typescript
// Only if absolutely necessary
export const userRouter = router({
  getWithStats: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      // Denormalized: user + stats in one query
      // Only do this if multiple queries are too slow
      const [user, postCount, orderTotal] = await Promise.all([
        ctx.prisma.user.findUnique({ where: { id: input.id } }),
        ctx.prisma.post.count({ where: { authorId: input.id } }),
        ctx.prisma.order.aggregate({
          where: { userId: input.id },
          _sum: { total: true },
        }),
      ]);

      return {
        ...user,
        stats: {
          postCount,
          orderTotal: orderTotal._sum.total ?? 0,
        },
      };
    }),
});
```

**Rule:** Start with multiple queries. Only denormalize if profiling shows it's necessary.

---

## Authentication Context

Add session/user to context:

```typescript
// src/server/trpc.ts
import { cookies } from 'next/headers';
import { prisma } from '@/lib/prisma';

export async function createContext() {
  const cookieStore = await cookies();
  const sessionId = cookieStore.get('session')?.value;

  let user = null;
  if (sessionId) {
    const session = await prisma.session.findUnique({
      where: { id: sessionId },
      include: { user: true },
    });
    user = session?.user ?? null;
  }

  return {
    prisma,
    user,
    sessionId,
  };
}
```

### Protected Procedures

```typescript
// src/server/trpc.ts
const t = initTRPC.context<Context>().create({
  transformer: superjson,
});

export const router = t.router;
export const publicProcedure = t.procedure;

// Protected procedure (requires authentication)
export const protectedProcedure = t.procedure.use(async ({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({
      code: 'UNAUTHORIZED',
      message: 'You must be logged in',
    });
  }
  return next({
    ctx: {
      ...ctx,
      user: ctx.user, // TypeScript now knows user exists
    },
  });
});
```

Usage:

```typescript
// src/server/routers/user.ts
export const userRouter = router({
  getMe: protectedProcedure.query(async ({ ctx }) => {
    // ctx.user is guaranteed to exist
    return ctx.user;
  }),

  updateProfile: protectedProcedure
    .input(z.object({ name: z.string() }))
    .mutation(async ({ ctx, input }) => {
      return ctx.prisma.user.update({
        where: { id: ctx.user.id },
        data: { name: input.name },
      });
    }),
});
```

---

## Cookie Writes (Rare Exception)

**Never use Server Actions.** The only exception is writing cookies in auth flows, and even then, use POST-redirect-GET pattern.

### POST-Redirect-GET Pattern

```typescript
// src/app/api/auth/login/route.ts
import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { z } from 'zod';

export async function POST(request: Request) {
  const body = await request.json();
  const { email, password } = z.object({
    email: z.string().email(),
    password: z.string(),
  }).parse(body);

  // Validate credentials
  const user = await validateCredentials(email, password);
  if (!user) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  // Create session
  const session = await prisma.session.create({
    data: { userId: user.id },
  });

  // Write cookie
  const cookieStore = await cookies();
  cookieStore.set('session', session.id, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7, // 7 days
  });

  // Redirect (POST-redirect-GET pattern)
  return NextResponse.redirect(new URL('/dashboard', request.url));
}
```

**Why POST-redirect-GET:**
- Prevents duplicate form submissions
- Browser back button works correctly
- Cookie is set before redirect

**When to use:**
- Login/logout flows
- Session creation/destruction
- That's it. Everything else uses tRPC.

---

## Testing

### Backend Tests

```typescript
// src/server/routers/user.test.ts
import { describe, test, expect, beforeAll } from 'bun:test';
import { appRouter } from '@/server/routers/_app';
import { createContext } from '@/server/trpc';
import { createTestDatabase } from '@/test/db';

describe('user router', () => {
  let prisma: PrismaClient;

  beforeAll(async () => {
    const db = await createTestDatabase();
    prisma = db.prisma;
  });

  test('getById returns user', async () => {
    const user = await prisma.user.create({
      data: { email: 'test@example.com', name: 'Test' },
    });

    const caller = appRouter.createCaller(createContext({ prisma }));
    const result = await caller.user.getById({ id: user.id });

    expect(result?.email).toBe('test@example.com');
  });
});
```

### Frontend Tests

Mock tRPC client:

```typescript
// src/hooks/use-user.test.ts
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { trpc, trpcClient } from '@/lib/trpc';
import { useUser } from './use-user';

test('useUser fetches user', async () => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });

  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </trpc.Provider>
  );

  const { result } = renderHook(() => useUser('1'), { wrapper });

  await waitFor(() => {
    expect(result.current.isLoading).toBe(false);
  });

  expect(result.current.user).toBeDefined();
});
```

---

## Performance Best Practices

### 1. Don't Overjoin

```typescript
// Bad: Everything in one query
getUserWithEverything: publicProcedure.query(async ({ ctx }) => {
  return ctx.prisma.user.findUnique({
    where: { id: userId },
    include: {
      posts: { include: { comments: { include: { author: true } } } },
      orders: { include: { items: { include: { product: true } } } },
      // ... 10 more relations
    },
  });
});

// Good: Focused queries
getUser: publicProcedure.query(...) // Just user
getUserPosts: publicProcedure.query(...) // Just posts
getUserOrders: publicProcedure.query(...) // Just orders
```

### 2. Use Parallel Queries

TanStack Query automatically batches parallel queries:

```typescript
// These run in parallel automatically
const { data: user } = trpc.user.getById.useQuery({ id: userId });
const { data: posts } = trpc.post.list.useQuery({ userId });
const { data: orders } = trpc.order.list.useQuery({ userId });
```

### 3. Denormalize Only When Necessary

Profile first. If multiple queries are slow, then consider denormalization.

---

## Checklist

Before using tRPC:

- [ ] Latest versions installed (`@trpc/server@latest`, etc.)
- [ ] superjson transformer configured (backend and frontend)
- [ ] TanStack Query provider wraps app
- [ ] No Server Actions (except rare cookie writes)
- [ ] Multiple focused queries instead of overjoining
- [ ] Protected procedures for authenticated routes
- [ ] Tests cover router procedures

---

## Quick Reference

```typescript
// Backend: Create router
export const userRouter = router({
  getById: publicProcedure
    .input(z.object({ id: z.string() }))
    .query(async ({ ctx, input }) => {
      return ctx.prisma.user.findUnique({ where: { id: input.id } });
    }),
});

// Frontend: Use query
const { data } = trpc.user.getById.useQuery({ id: userId });

// Frontend: Use mutation
const create = trpc.user.create.useMutation();
create.mutate({ email, name });
```

---

## Related

- [Frontend Architecture](./frontend.md) - Component patterns with tRPC
- [Authentication](./auth.md) - Session management with tRPC
- [Project Setup](./setup.md) - Installing tRPC in new projects
- [Implement Ticket](./implement-ticket.md) - Using tRPC in ticket workflow
