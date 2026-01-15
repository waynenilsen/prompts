# Bootstrap Scripts

Modular bootstrap scripts for creating new projects with the full stack.

## Structure

- `bootstrap.sh` - Main orchestrator script
- `common.sh` - Shared utilities (logging, colors, helpers)
- `scripts/` - Individual setup scripts:
  - `01-setup-nextjs.sh` - Create Next.js project and clean up defaults
  - `02-setup-biome.sh` - Configure Biome
  - `03-setup-prisma.sh` - Setup Prisma with SQLite
  - `04-setup-trpc.sh` - Setup tRPC with TanStack Query
  - `05-setup-shadcn.sh` - Setup shadcn/ui with all components
  - `06-setup-email.sh` - Setup React Email and Mailhog
  - `07-setup-typedoc.sh` - Setup TypeDoc
  - `08-setup-testing.sh` - Setup Bun test and Playwright
  - `09-setup-env.sh` - Setup environment files and scripts

## Usage

```bash
./bootstrap/bootstrap.sh my-app
./bootstrap/bootstrap.sh ~/projects/my-app
```

## Design Principles

- **Modular**: Each script has a single responsibility
- **Idempotent**: Scripts can be run independently (with proper context)
- **Clear**: Each script is focused and easy to understand
- **Maintainable**: Easy to add new setup steps or modify existing ones
