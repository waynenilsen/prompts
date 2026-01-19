#!/usr/bin/env bash
#
# bootstrap.sh - Bootstrap a new project with the full stack
#
# Usage:
#   ./bootstrap/bootstrap.sh <path>
#   ./bootstrap/bootstrap.sh my-app
#   ./bootstrap/bootstrap.sh ~/projects/foo/bar/my-app
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOTSTRAP_DIR="$SCRIPT_DIR"
PROMPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$BOOTSTRAP_DIR/common.sh"

# Validate arguments
if [ -z "${1:-}" ]; then
  echo "Usage: bootstrap/bootstrap.sh <path>"
  echo "  e.g., bootstrap/bootstrap.sh my-app"
  echo "  e.g., bootstrap/bootstrap.sh ~/projects/foo/bar/my-app"
  exit 1
fi

TARGET_PATH="$1"
PROJECT_NAME="$(basename "$TARGET_PATH")"
PARENT_DIR="$(dirname "$TARGET_PATH")"

# Create parent directories if they don't exist
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

# Generate random ports
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

# Export for use in sub-scripts
export MAILHOG_SMTP_PORT
export MAILHOG_WEB_PORT
export DEV_PORT
export BOOTSTRAP_DIR
export PROMPTS_DIR

# Step 1: Create Next.js project and clean it up
log "Step 1: Creating Next.js project"
"$BOOTSTRAP_DIR/scripts/01-setup-nextjs.sh" "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Step 2: Configure Biome
log "Step 2: Configuring Biome"
"$BOOTSTRAP_DIR/scripts/02-setup-biome.sh"

# Step 3: Setup Prisma
log "Step 3: Setting up Prisma"
"$BOOTSTRAP_DIR/scripts/03-setup-prisma.sh"

# Step 4: Setup tRPC
log "Step 4: Setting up tRPC"
"$BOOTSTRAP_DIR/scripts/04-setup-trpc.sh"

# Step 5: Setup shadcn/ui
log "Step 5: Setting up shadcn/ui"
"$BOOTSTRAP_DIR/scripts/05-setup-shadcn.sh"

# Step 6: Setup Email
log "Step 6: Setting up Email"
"$BOOTSTRAP_DIR/scripts/06-setup-email.sh"

# Step 7: Setup TypeDoc
log "Step 7: Setting up TypeDoc"
"$BOOTSTRAP_DIR/scripts/07-setup-typedoc.sh"

# Step 8: Setup Testing
log "Step 8: Setting up Testing"
"$BOOTSTRAP_DIR/scripts/08-setup-testing.sh"

# Step 9: Setup Environment
log "Step 9: Setting up Environment"
"$BOOTSTRAP_DIR/scripts/09-setup-env.sh"

# Step 10: Setup README
log "Step 10: Setting up README"
"$BOOTSTRAP_DIR/scripts/10-setup-readme.sh"

# Step 11: Setup AGENTS.md
log "Step 11: Setting up AGENTS.md"
"$BOOTSTRAP_DIR/scripts/11-setup-agents.sh"

# Step 12: Install prompts
log "Step 12: Installing prompts"
"$PROMPTS_DIR/install.sh" "$(pwd)"

# Step 13: Generate Prisma client and push schema
log "Step 13: Generating Prisma client"
bunx prisma generate
bunx prisma db push
success "Prisma client generated and schema pushed"

# Step 14: Verify setup
log "Step 14: Verifying setup..."

# Format code first
log "Formatting code with Biome..."
bunx biome format --write . || error "Biome format failed"

# Run Biome check with autofix - keep running until clean
log "Running Biome check and autofix (iterating until clean)..."
MAX_ITERATIONS=5
ITERATION=0
while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))
  echo -e "${DIM}Biome check iteration $ITERATION...${RESET}"
  
  # Run check with autofix (including unsafe fixes) and max diagnostics
  # --write flag formats AND fixes linting issues
  if bunx biome check --write --unsafe --max-diagnostics=10000 . 2>&1 | tee /tmp/biome-check.log; then
    success "Biome check passed (clean)"
    break
  else
    # Check if there are any remaining errors (not just warnings)
    if grep -q "Found [1-9][0-9]* errors" /tmp/biome-check.log; then
      if [ $ITERATION -eq $MAX_ITERATIONS ]; then
        error "Biome check failed after $MAX_ITERATIONS iterations. Remaining errors need manual fixes."
      else
        echo -e "${DIM}Biome found errors, auto-fixing and retrying...${RESET}"
        sleep 1
      fi
    else
      success "Biome check passed (only warnings)"
      break
    fi
  fi
done

# Final format pass to ensure everything is formatted
log "Final formatting pass..."
bunx biome format --write . || error "Final Biome format failed"
success "Code formatted and linted"

echo -e "${DIM}Running: bun run docs${RESET}"
bun run docs || error "Documentation generation failed - all exported functions, methods, classes, interfaces, type aliases, and variables must have JSDoc comments"

echo -e "${DIM}Running: bun test${RESET}"
bun test || error "Unit tests failed"

echo -e "${DIM}Running: bun run build${RESET}"
bun run build || error "Build failed"

echo -e "${DIM}Running: bun run test:e2e${RESET}"
if bun run test:e2e; then
  success "E2E tests passed"
else
  echo -e "${DIM}E2E tests skipped (browser dependencies may be missing)${RESET}"
  echo -e "${DIM}Run 'bunx playwright install-deps' to install system dependencies${RESET}"
fi

success "Bootstrap completed - all checks passed!"

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
