#!/usr/bin/env bash
# Create AGENTS.md for AI coding assistants

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Creating AGENTS.md"

cat > AGENTS.md << 'EOF'
# Agent Guidelines

This file provides context for AI coding assistants working on this codebase.

## Prompts Directory

The `@prompts/` folder contains detailed guidelines and best practices. Reference these to avoid context rot - pull in only what you need for the current task:

- `@prompts/db.md` - Database schema conventions, Prisma patterns, migrations
- `@prompts/frontend.md` - React/Next.js patterns, component structure, styling
- `@prompts/testing.md` - Test patterns, coverage requirements, E2E testing

## Stack Overview

| Layer | Technology |
|-------|------------|
| Framework | Next.js 15 (App Router, Turbopack) |
| Language | TypeScript (strict mode) |
| Styling | Tailwind CSS v4 + shadcn/ui |
| API | tRPC + TanStack Query |
| Database | Prisma + SQLite |
| Email | React Email |
| Testing | Bun test + Playwright |
| Tooling | Biome (format/lint) |

## Key Patterns

### API Routes
- All API logic goes through tRPC routers in `src/server/routers/`
- Use `publicProcedure` for unauthenticated routes
- Input validation with Zod schemas

### Database
- Multi-file Prisma schema in `prisma/` directory
- All tables use CUID for primary keys
- Run `bun run db:push` after schema changes

### Components
- shadcn/ui components in `src/components/ui/` (do not modify)
- Custom components elsewhere in `src/components/`
- Use `cn()` utility for conditional class merging

### Testing
- Unit tests: `*.test.ts` files next to source
- E2E tests: `e2e/*.e2e.ts`
- 95% coverage threshold enforced

## Commands

```bash
bun run dev          # Start dev server
bun run check        # Format + lint with autofixes
bun test             # Run unit tests
bun run test:e2e     # Run E2E tests
bun run db:push      # Push schema changes
bun run db:studio    # Open Prisma Studio
```

## File Structure

```
src/
├── app/              # Next.js pages and API routes
├── components/ui/    # shadcn/ui (don't modify)
├── emails/           # React Email templates
├── lib/              # Shared utilities
│   ├── prisma.ts     # Database client
│   ├── trpc.ts       # tRPC client
│   └── email.ts      # Email service
└── server/           # Backend code
    ├── trpc.ts       # tRPC setup
    └── routers/      # API routers
prisma/               # Database schema files
e2e/                  # Playwright tests
```
EOF

# Symlink CLAUDE.md to AGENTS.md so Claude Code picks it up
ln -sf AGENTS.md CLAUDE.md

success "AGENTS.md created (CLAUDE.md symlinked)"
