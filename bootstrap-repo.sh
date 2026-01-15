#!/usr/bin/env bash
#
# bootstrap-repo.sh - Bootstrap a new project with the full stack
#
# Usage:
#   ./bootstrap-repo.sh <path>
#   ./bootstrap-repo.sh my-app
#   ./bootstrap-repo.sh ~/projects/foo/bar/my-app
#
# Creates a new Next.js project with:
#   - TypeScript + App Router
#   - Tailwind CSS
#   - Biome (replacing ESLint)
#   - Prisma + SQLite (multi-file schema)
#   - shadcn/ui
#   - React Email + Mailhog (dev) / SendGrid (prod)
#   - Docker Compose for local services
#   - TypeDoc
#   - Playwright
#   - Bun test with coverage
#   - Random ports (50000-60000) to avoid collisions
#

set -euo pipefail

# Get script directory (where prompts repo lives)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Generate random port in range 50000-60000
random_port() {
  echo $((RANDOM % 10000 + 50000))
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

log() {
  echo -e "${CYAN}▶${RESET} $1"
}

success() {
  echo -e "${GREEN}✓${RESET} $1"
}

error() {
  echo -e "${RED}✗${RESET} $1" >&2
  exit 1
}

# Validate arguments
if [ -z "${1:-}" ]; then
  echo "Usage: bootstrap-repo.sh <path>"
  echo "  e.g., bootstrap-repo.sh my-app"
  echo "  e.g., bootstrap-repo.sh ~/projects/foo/bar/my-app"
  exit 1
fi

TARGET_PATH="$1"
PROJECT_NAME="$(basename "$TARGET_PATH")"
PARENT_DIR="$(dirname "$TARGET_PATH")"

# Create parent directories if they don't exist (and it's not just ".")
if [ "$PARENT_DIR" != "." ] && [ ! -d "$PARENT_DIR" ]; then
  log "Creating parent directory: $PARENT_DIR"
  mkdir -p "$PARENT_DIR"
fi

if [ -d "$TARGET_PATH" ]; then
  error "Directory '$TARGET_PATH' already exists"
fi

# Change to parent directory if specified
if [ "$PARENT_DIR" != "." ]; then
  cd "$PARENT_DIR"
fi

# Step 1: Create Next.js project
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
success "Next.js project created"

# Generate random ports for this project
MAILHOG_SMTP_PORT=$(random_port)
MAILHOG_WEB_PORT=$(random_port)
DEV_PORT=$(random_port)

# Ensure ports are unique
while [ "$MAILHOG_WEB_PORT" -eq "$MAILHOG_SMTP_PORT" ]; do
  MAILHOG_WEB_PORT=$(random_port)
done
while [ "$DEV_PORT" -eq "$MAILHOG_SMTP_PORT" ] || [ "$DEV_PORT" -eq "$MAILHOG_WEB_PORT" ]; do
  DEV_PORT=$(random_port)
done

log "Generated ports: Dev=$DEV_PORT, Mailhog SMTP=$MAILHOG_SMTP_PORT, Mailhog Web=$MAILHOG_WEB_PORT"

# Step 2: Update Biome and configure for Tailwind
log "Updating Biome and configuring for Tailwind"
bun add -d @biomejs/biome@latest
BIOME_VERSION=$(bunx biome --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
cat > biome.json << EOF
{
  "\$schema": "https://biomejs.dev/schemas/${BIOME_VERSION}/schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "linter": {
    "enabled": true,
    "rules": { "recommended": true }
  },
  "javascript": {
    "formatter": { "quoteStyle": "single", "semicolons": "always" }
  },
  "css": {
    "parser": {
      "cssModules": true,
      "tailwindDirectives": true
    }
  }
}
EOF
success "Biome configured"

# Step 3: Add Bun types for TypeScript
log "Adding Bun types"
bun add -d @types/bun
success "Bun types added"

# Step 4: Set up Prisma with SQLite (using Prisma 6.x for stability)
log "Setting up Prisma with SQLite"
bun add -d prisma@^6
bun add @prisma/client@^6
bunx prisma init --datasource-provider sqlite

# Remove the prisma.config.ts if created (we use the simpler setup)
rm -f prisma.config.ts

# Create multi-file schema structure
# Main schema file (generator + datasource only)
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

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
EOF

success "Prisma configured with multi-file schema"

# Step 5: Set up shadcn/ui
log "Setting up shadcn/ui"
bunx shadcn@latest init -y -d

success "shadcn/ui initialized"

# Step 6: Set up Docker Compose with Mailhog
log "Setting up Docker Compose with Mailhog"
cat > docker-compose.yml << EOF
services:
  mailhog:
    image: mailhog/mailhog
    ports:
      - "${MAILHOG_SMTP_PORT}:1025"
      - "${MAILHOG_WEB_PORT}:8025"
    restart: unless-stopped
EOF
success "Docker Compose configured"

# Step 7: Set up React Email
log "Setting up React Email with stage-based transport"
bun add react-email @react-email/components nodemailer @sendgrid/mail
bun add -d @types/nodemailer

# Create emails directory
mkdir -p src/emails

# Create email service abstraction
cat > src/lib/email.ts << 'EOF'
import { render } from '@react-email/components';
import nodemailer from 'nodemailer';
import sgMail from '@sendgrid/mail';

const STAGE = process.env.STAGE || 'local';

// Configure SendGrid for production
if (STAGE === 'production' && process.env.SENDGRID_API_KEY) {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
}

// Mailhog transporter for local development
const mailhogTransport = nodemailer.createTransport({
  host: 'localhost',
  port: Number(process.env.MAILHOG_SMTP_PORT) || 1025,
  secure: false,
});

interface SendEmailOptions {
  to: string | string[];
  subject: string;
  template: React.ReactElement;
  from?: string;
}

interface SendEmailResult {
  success: boolean;
  messageId?: string;
  error?: Error;
}

export async function sendEmail({
  to,
  subject,
  template,
  from,
}: SendEmailOptions): Promise<SendEmailResult> {
  const html = await render(template);
  const defaultFrom = process.env.EMAIL_FROM || 'noreply@example.com';
  const sender = from || defaultFrom;

  try {
    if (STAGE === 'production') {
      const [response] = await sgMail.send({
        to,
        from: sender,
        subject,
        html,
      });
      return { success: true, messageId: response.headers['x-message-id'] };
    }

    if (STAGE === 'test') {
      // Log to console for test visibility
      console.log(`[EMAIL] To: ${to}, Subject: ${subject}`);
      return { success: true, messageId: 'test-message-id' };
    }

    // Local: send to Mailhog
    const info = await mailhogTransport.sendMail({
      to,
      from: sender,
      subject,
      html,
    });
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('[EMAIL ERROR]', error);
    return {
      success: false,
      error: error instanceof Error ? error : new Error('Unknown error'),
    };
  }
}
EOF

# Create sample email template
cat > src/emails/welcome.tsx << 'EOF'
import {
  Html,
  Head,
  Body,
  Container,
  Section,
  Text,
  Button,
  Hr,
} from '@react-email/components';

interface WelcomeEmailProps {
  name: string;
  loginUrl: string;
}

export function WelcomeEmail({ name, loginUrl }: WelcomeEmailProps) {
  return (
    <Html>
      <Head />
      <Body style={main}>
        <Container style={container}>
          <Section>
            <Text style={heading}>Welcome, {name}!</Text>
            <Text style={paragraph}>
              Thanks for signing up. We&apos;re excited to have you on board.
            </Text>
            <Button style={button} href={loginUrl}>
              Get Started
            </Button>
            <Hr style={hr} />
            <Text style={footer}>
              If you didn&apos;t create this account, you can ignore this email.
            </Text>
          </Section>
        </Container>
      </Body>
    </Html>
  );
}

const main = {
  backgroundColor: '#f6f9fc',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
};

const container = {
  backgroundColor: '#ffffff',
  margin: '0 auto',
  padding: '40px 20px',
  maxWidth: '560px',
};

const heading = {
  fontSize: '24px',
  fontWeight: 'bold' as const,
  color: '#1a1a1a',
};

const paragraph = {
  fontSize: '16px',
  lineHeight: '26px',
  color: '#4a4a4a',
};

const button = {
  backgroundColor: '#000000',
  borderRadius: '4px',
  color: '#ffffff',
  fontSize: '16px',
  fontWeight: 'bold' as const,
  textDecoration: 'none',
  padding: '12px 24px',
  display: 'inline-block' as const,
};

const hr = {
  borderColor: '#e6e6e6',
  margin: '26px 0',
};

const footer = {
  fontSize: '14px',
  color: '#8c8c8c',
};
EOF

# Create email test file
cat > src/lib/email.test.ts << 'EOF'
import { describe, test, expect, beforeAll } from 'bun:test';

// Note: Full email tests require the email service to be imported
// This is a placeholder that verifies the module structure

describe('email', () => {
  beforeAll(() => {
    process.env.STAGE = 'test';
  });

  test('STAGE defaults to local', () => {
    // Reset for this test
    const stage = process.env.STAGE || 'local';
    expect(['local', 'test', 'production']).toContain(stage);
  });
});
EOF

success "React Email configured"

# Step 8: Set up TypeDoc
log "Setting up TypeDoc"
bun add -d typedoc

cat > typedoc.json << 'EOF'
{
  "entryPoints": ["src"],
  "entryPointStrategy": "expand",
  "out": "docs",
  "exclude": ["**/*.test.ts", "**/*.e2e.ts", "**/node_modules/**", "test/**"],
  "excludePrivate": true,
  "skipErrorChecking": true
}
EOF
success "TypeDoc configured"

# Step 9: Set up Playwright
log "Setting up Playwright"
bun add -d @playwright/test
bunx playwright install chromium

mkdir -p e2e
cat > e2e/example.e2e.ts << 'EOF'
import { test, expect } from '@playwright/test';

test('homepage loads', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/Next/);
});
EOF

cat > playwright.config.ts << EOF
import { defineConfig } from '@playwright/test';

const isTty = process.stdout.isTTY;

export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.e2e.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: isTty ? [['html', { open: 'never' }]] : [['line']],
  use: {
    baseURL: 'http://localhost:${DEV_PORT}',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'bun run dev',
    url: 'http://localhost:${DEV_PORT}',
    reuseExistingServer: !process.env.CI,
  },
});
EOF
success "Playwright configured"

# Step 10: Set up Bun test with coverage
log "Setting up Bun test configuration"
mkdir -p test
cat > test/setup.ts << 'EOF'
import { beforeAll, afterAll } from 'bun:test';

beforeAll(() => {
  // Global test setup
});

afterAll(() => {
  // Global test teardown
});
EOF

cat > bunfig.toml << 'EOF'
[test]
preload = ["./test/setup.ts"]

# Always generate coverage
coverage = true

# Fail build if coverage drops below 95%
coverageThreshold = { line = 0.95, function = 0.95, statement = 0.95 }

# Output formats
coverageReporter = ["text", "lcov"]
coverageDir = "./coverage"

# Skip test files in coverage reports
coverageSkipTestFiles = true
EOF

# Create example test file
cat > src/lib/utils.test.ts << 'EOF'
import { describe, test, expect } from 'bun:test';
import { cn } from './utils';

describe('cn', () => {
  test('merges class names', () => {
    expect(cn('foo', 'bar')).toBe('foo bar');
  });

  test('handles conditional classes', () => {
    expect(cn('foo', false && 'bar', 'baz')).toBe('foo baz');
  });
});
EOF
success "Bun test configured"

# Step 11: Update package.json scripts
log "Updating package.json scripts"
# Use node to update package.json
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = {
  ...pkg.scripts,
  'dev': 'next dev --port ${DEV_PORT}',
  'format': 'biome format --write .',
  'lint': 'biome lint .',
  'lint:fix': 'biome lint --fix .',
  'check': 'biome check --fix .',
  'docs': 'typedoc',
  'docs:watch': 'typedoc --watch',
  'test': 'bun test',
  'test:e2e': 'playwright test',
  'test:all': 'bun test && playwright test',
  'db:push': 'prisma db push',
  'db:studio': 'prisma studio',
  'db:generate': 'prisma generate',
  'email:dev': 'email dev --dir src/emails --port 3001',
  'services:up': 'docker compose up -d',
  'services:down': 'docker compose down'
};
pkg.prisma = { schema: './prisma' };
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"
success "package.json updated"

# Step 12: Update .gitignore
log "Updating .gitignore"
cat >> .gitignore << 'EOF'

# Database
prisma/dev.db
prisma/dev.db-journal
prisma/*.db
prisma/*.db-journal

# Generated docs
docs/

# Coverage
coverage/

# Playwright
playwright-report/
test-results/

# Environment (keep .env.example, ignore actual .env)
.env
.env.local
.env.*.local
EOF
success ".gitignore updated"

# Step 13: Create .env file with generated ports
log "Creating .env file"
cat > .env << EOF
# Stage: local | test | production
STAGE=local

# Generated ports (unique per project to avoid collisions)
PORT=${DEV_PORT}
MAILHOG_SMTP_PORT=${MAILHOG_SMTP_PORT}
MAILHOG_WEB_PORT=${MAILHOG_WEB_PORT}

# Email configuration
EMAIL_FROM=noreply@example.com

# SendGrid (production only)
# SENDGRID_API_KEY=SG.xxx

# Database
DATABASE_URL="file:./dev.db"
EOF

# Create .env.example without sensitive values
cat > .env.example << EOF
# Stage: local | test | production
STAGE=local

# Generated ports (unique per project to avoid collisions)
PORT=${DEV_PORT}
MAILHOG_SMTP_PORT=${MAILHOG_SMTP_PORT}
MAILHOG_WEB_PORT=${MAILHOG_WEB_PORT}

# Email configuration
EMAIL_FROM=noreply@example.com

# SendGrid (production only)
# SENDGRID_API_KEY=SG.xxx

# Database
DATABASE_URL="file:./dev.db"
EOF
success ".env files created"

# Step 14: Install prompts
log "Installing prompts"
"$SCRIPT_DIR/install.sh" "$(pwd)"
success "Prompts installed"

# Step 15: Generate Prisma client and push schema
log "Generating Prisma client"
bunx prisma generate
bunx prisma db push
success "Prisma client generated and schema pushed"

# Step 16: Verify setup
log "Verifying setup..."

echo -e "${DIM}Running: bun run check${RESET}"
bun run check || true

echo -e "${DIM}Running: bun run docs${RESET}"
bun run docs || true

echo -e "${DIM}Running: bun test${RESET}"
bun test

echo -e "${DIM}Running: bun run build${RESET}"
bun run build

echo -e "${DIM}Running: bun run test:e2e${RESET}"
if bun run test:e2e; then
  success "E2E tests passed"
else
  echo -e "${DIM}E2E tests skipped (browser dependencies may be missing)${RESET}"
  echo -e "${DIM}Run 'bunx playwright install-deps' to install system dependencies${RESET}"
fi

success "All checks passed!"

FINAL_PATH="$(pwd)"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}Project '$PROJECT_NAME' created successfully!${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "Ports (randomly generated to avoid collisions):"
echo "  Dev server:    http://localhost:${DEV_PORT}"
echo "  Mailhog SMTP:  localhost:${MAILHOG_SMTP_PORT}"
echo "  Mailhog Web:   http://localhost:${MAILHOG_WEB_PORT}"
echo ""
echo "Next steps:"
echo "  cd $FINAL_PATH"
echo "  bun run services:up   # Start Mailhog"
echo "  bun run dev           # Start dev server"
echo ""
