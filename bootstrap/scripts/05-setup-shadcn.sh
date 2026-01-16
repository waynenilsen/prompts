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

# Add documentation to utils.ts (shadcn may have overwritten it)
if [ -f src/lib/utils.ts ]; then
  # Add JSDoc comment to cn function if it doesn't already have one
  if ! grep -q "/\*\*" src/lib/utils.ts; then
    sed -i.bak '/^export function cn(/i\
/**\
 * Merges class names with Tailwind CSS conflict resolution.\
 * Combines clsx and tailwind-merge to handle conditional classes and Tailwind conflicts.\
 *\
 * @param inputs - Class names or conditional class objects\
 * @returns Merged class string\
 */\
' src/lib/utils.ts
    rm -f src/lib/utils.ts.bak
  fi
fi

# Add documentation to use-mobile hook if it exists
if [ -f src/hooks/use-mobile.ts ]; then
  # Add JSDoc comment to useIsMobile function if it doesn't already have one
  if ! grep -q "/\*\*" src/hooks/use-mobile.ts; then
    sed -i.bak 's/^export function useIsMobile() {/\/**\n * Hook to detect mobile viewport.\n * Returns true if the viewport width is less than 768px.\n *\/\nexport function useIsMobile() {/' src/hooks/use-mobile.ts
    rm -f src/hooks/use-mobile.ts.bak
  fi
fi

success "shadcn/ui initialized with all components (resizable excluded)"
