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
  "exclude": ["**/*.test.ts", "**/*.e2e.ts", "**/node_modules/**", "test/**", "src/components/ui/**"],
  "excludePrivate": true,
  "skipErrorChecking": false,
  "validation": {
    "notDocumented": true
  },
  "requiredToBeDocumented": [
    "Function",
    "Method",
    "Class",
    "Interface",
    "TypeAlias",
    "Variable"
  ],
  "treatValidationWarningsAsErrors": true
}
EOF

success "TypeDoc configured"
