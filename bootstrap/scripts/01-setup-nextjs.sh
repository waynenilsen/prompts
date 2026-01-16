#!/usr/bin/env bash
# Setup Next.js project and clean up default content

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"

PROJECT_NAME="$1"

log "Creating Next.js project: $PROJECT_NAME"
bunx create-next-app@latest "$PROJECT_NAME" \
  --typescript \
  --tailwind \
  --biome \
  --app \
  --src-dir \
  --turbopack \
  --import-alias "@/*" \
  --yes \
  --use-bun

cd "$PROJECT_NAME"

log "Cleaning up Next.js default content"

# Remove default page content and replace with hello world using tRPC
cat > src/app/page.tsx << 'EOF'
'use client';

import { useState } from 'react';
import { trpc } from '@/lib/trpc';

export default function Home() {
  const [name, setName] = useState('World');
  const { data, isLoading } = trpc.hello.useQuery({ name });

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <form
        onSubmit={(e) => {
          e.preventDefault();
        }}
        className="flex flex-col items-center gap-4"
      >
        <input
          data-testid="name-input"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Enter your name"
          className="rounded-md border border-input bg-background px-4 py-2 text-lg"
        />
        <h1 data-testid="greeting" className="text-4xl font-bold">
          {isLoading ? 'Loading...' : data}
        </h1>
      </form>
      <p className="mt-4 text-lg text-muted-foreground">
        Your Next.js app is ready!
      </p>
    </main>
  );
}
EOF

# Clean up globals.css - keep Tailwind v4 structure, remove Next.js defaults
# Let shadcn/ui add its theme when it initializes
cat > src/app/globals.css << 'EOF'
@import "tailwindcss";
@import "tw-animate-css";

@custom-variant dark (&:where(.dark, .dark *));
EOF

# Update layout.tsx to minimal
cat > src/app/layout.tsx << 'EOF'
import type { Metadata } from 'next';
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
      <body>{children}</body>
    </html>
  );
}
EOF

# Remove default favicon and other Next.js defaults
rm -f src/app/favicon.ico
rm -rf src/app/*/page.tsx 2>/dev/null || true

# Add Bun types
log "Adding Bun types"
bun add -d @types/bun

# Create utils.ts (needed for tests)
mkdir -p src/lib
cat > src/lib/utils.ts << 'EOF'
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
EOF

# Install utils dependencies
bun add clsx tailwind-merge

success "Next.js project created and cleaned up"
