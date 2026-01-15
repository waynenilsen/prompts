# prompts

Opinionated development workflow prompts for building zero-configuration deployable applications.

## The Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js (App Router) |
| API | tRPC + TanStack Query |
| Styling | Tailwind CSS |
| Components | shadcn/ui |
| Database | Prisma + SQLite |
| Email | React Email + Mailhog (dev) / SendGrid (prod) |
| Runtime | Bun |
| Hosting | Sprite |

## Key Constraints

- **No external services** unless explicitly requested
- **Run on checkout** — clone, install, run
- **GitHub CLI (`gh`)** for all ticket operations
- **Test-near-code** — unit tests next to source files
- **tRPC for all APIs** — never use Server Actions (except rare cookie writes)

## Documentation

- [./dev](./dev/index.md) - Development guidelines and conventions
- [./product](./product/index.md) - Product planning and requirements
- [./promptgrams](./promptgrams/index.md) - Structured workflow prompts
