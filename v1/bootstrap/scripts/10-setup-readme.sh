#!/usr/bin/env bash
# Replace default Next.js README with project-specific one

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Replacing default README"

cat > README.md << 'EOF'
# Project

## Getting Started

```bash
bun install
bun run services:up   # Start Mailhog
bun run dev           # Start dev server
```

## Scripts

| Command | Description |
|---------|-------------|
| `bun run dev` | Start development server |
| `bun run build` | Build for production |
| `bun run start` | Start production server |
| `bun run format` | Format code with Biome |
| `bun run lint` | Lint code with Biome |
| `bun run check` | Format and lint with autofixes |
| `bun test` | Run unit tests |
| `bun run test:e2e` | Run Playwright E2E tests |
| `bun run test:all` | Run all tests |
| `bun run docs` | Generate TypeDoc documentation |
| `bun run db:push` | Push Prisma schema to database |
| `bun run db:studio` | Open Prisma Studio |
| `bun run email:dev` | Preview email templates |
| `bun run services:up` | Start Docker services (Mailhog) |
| `bun run services:down` | Stop Docker services |

## Stack

- **Framework**: Next.js (App Router, Turbopack)
- **Language**: TypeScript
- **Styling**: Tailwind CSS v4 + shadcn/ui
- **API**: tRPC + TanStack Query
- **Database**: Prisma + SQLite
- **Email**: React Email (Mailhog local, SendGrid production)
- **Testing**: Bun test + Playwright
- **Tooling**: Biome (format/lint), TypeDoc

## Project Structure

```
src/
├── app/              # Next.js App Router pages
├── components/ui/    # shadcn/ui components
├── emails/           # React Email templates
├── lib/              # Shared utilities (prisma, trpc, email)
└── server/           # tRPC routers and server code
prisma/               # Database schema (multi-file)
e2e/                  # Playwright E2E tests
test/                 # Test setup and utilities
```
EOF

success "README created"
