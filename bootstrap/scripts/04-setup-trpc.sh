#!/usr/bin/env bash
# Setup tRPC with TanStack Query

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Setting up tRPC with TanStack Query"
bun add @trpc/server@latest @trpc/client@latest @trpc/react-query@latest @trpc/next@latest
bun add @tanstack/react-query@latest
bun add superjson zod

# Create tRPC server setup
mkdir -p src/server/routers
cat > src/server/trpc.ts << 'EOF'
import { initTRPC } from '@trpc/server';
import superjson from 'superjson';
import { prisma } from '@/lib/prisma';

export function createContext() {
  return { prisma };
}

type Context = Awaited<ReturnType<typeof createContext>>;

const t = initTRPC.context<Context>().create({
  transformer: superjson,
});

export const router = t.router;
export const publicProcedure = t.procedure;
EOF

# Create root router
cat > src/server/routers/_app.ts << 'EOF'
import { router, publicProcedure } from '@/server/trpc';
import { z } from 'zod';

export const appRouter = router({
  hello: publicProcedure
    .input(z.object({ name: z.string() }))
    .query(({ input }) => {
      return `Hello ${input.name}`;
    }),
});

export type AppRouter = typeof appRouter;
EOF

# Create API route handler
mkdir -p src/app/api/trpc/\[trpc\]
cat > src/app/api/trpc/\[trpc\]/route.ts << 'EOF'
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
EOF

# Create tRPC client
cat > src/lib/trpc.ts << 'EOF'
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
EOF

# Create providers component
cat > src/app/providers.tsx << 'EOF'
'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';
import { trpc, trpcClient } from '@/lib/trpc';

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </trpc.Provider>
  );
}
EOF

# Update layout.tsx to include providers
cat > src/app/layout.tsx << 'EOF'
import type { Metadata } from 'next';
import { Providers } from './providers';
import './globals.css';

export const metadata: Metadata = {
  title: 'Next.js App',
  description: 'Generated with bootstrap',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
EOF

success "tRPC configured"
