#!/usr/bin/env bash
# Setup Prisma with SQLite (multi-file schema)

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Setting up Prisma with SQLite"
bun add -d prisma@^6
bun add @prisma/client@^6
bunx prisma init --datasource-provider sqlite

# Remove the prisma.config.ts if created
rm -f prisma.config.ts

# Create multi-file schema structure
cat > prisma/schema.prisma << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}
EOF

# Example User model in separate file
cat > prisma/user.prisma << 'EOF'
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
EOF

# Create Prisma client singleton
mkdir -p src/lib
cat > src/lib/prisma.ts << 'EOF'
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

/**
 * Prisma client singleton instance.
 * In development, reuses the same instance across hot reloads.
 */
export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
EOF

success "Prisma configured with multi-file schema"
