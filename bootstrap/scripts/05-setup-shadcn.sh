#!/usr/bin/env bash
# Setup shadcn/ui with all components

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Setting up shadcn/ui"
bunx shadcn@latest init -y -d

log "Adding all shadcn/ui components"
bunx shadcn@latest add --all --yes

log "Removing problematic resizable component (TypeScript error)"
rm -f src/components/ui/resizable.tsx

success "shadcn/ui initialized with all components (resizable excluded)"
