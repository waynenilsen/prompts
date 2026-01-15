#!/usr/bin/env bash
# Setup TypeDoc

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

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
