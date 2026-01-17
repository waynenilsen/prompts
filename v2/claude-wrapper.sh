#!/usr/bin/env bash
#
# claude-wrapper.sh - Wrapper for claude command with standard flags
#
# Usage:
#   ./claude-wrapper.sh "<any prompt string>"

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: claude-wrapper.sh <prompt>"
  echo "  e.g., claude-wrapper.sh \"run the promptgram @promptgrams/ralph.md\""
  exit 1
fi

PROMPT="$1"

claude -p "$PROMPT" \
  --dangerously-skip-permissions \
  --output-format stream-json \
  --verbose | cclean
