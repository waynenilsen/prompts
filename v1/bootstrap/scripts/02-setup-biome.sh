#!/usr/bin/env bash
# Setup Biome for formatting and linting

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BOOTSTRAP_DIR/common.sh"
ensure_project_dir

log "Updating Biome and configuring for Tailwind"
bun add -d @biomejs/biome@latest
BIOME_VERSION=$(bunx biome --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

cat > biome.json << EOF
{
  "\$schema": "https://biomejs.dev/schemas/${BIOME_VERSION}/schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "files": {
    "includes": ["**", "!src/components/ui/**"]
  },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "suspicious": {
        "noUnknownAtRules": "off"
      }
    }
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
