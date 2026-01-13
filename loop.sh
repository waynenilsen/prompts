#!/usr/bin/env bash
#
# loop.sh - Run ralph in a continuous development loop
#
# Usage:
#   ./loop.sh          # Run indefinitely
#   ./loop.sh 5        # Run 5 iterations
#
# Each iteration:
#   1. Runs @promptgrams/ralph.md
#   2. Pushes changes to remote
#   3. Repeats
#

set -euo pipefail

MAX_ITERATIONS="${1:-0}"  # 0 = unlimited
ITERATION=0

# Colors
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

run_ralph() {
  claude -p "@promptgrams/ralph.md" \
    --dangerously-skip-permissions \
    --output-format stream-json \
    --model claude-sonnet-4-20250514 \
    --verbose 2>/dev/null | jq -r '
      # Text from assistant messages
      if .type == "message" and .role == "assistant" then
        (.content // [])[] | select(.type == "text") | .text // empty

      # Tool invocations
      elif .type == "tool_use" then
        if .name == "Bash" then
          "$ \(.input.command)"
        elif .name == "Read" then
          "\u001b[2m📖 \(.input.file_path)\u001b[0m"
        elif .name == "WebSearch" then
          "\u001b[36m🔍 \(.input.query)\u001b[0m"
        elif .name == "WebFetch" then
          "\u001b[36m🌐 \(.input.url)\u001b[0m"
        elif .name == "Grep" then
          "\u001b[2m🔎 \(.input.pattern)\u001b[0m"
        elif .name == "Glob" then
          "\u001b[2m📁 \(.input.pattern)\u001b[0m"
        elif .name == "Edit" then
          "\u001b[2m✏️  \(.input.file_path)\u001b[0m"
        elif .name == "Write" then
          "\u001b[2m📝 \(.input.file_path)\u001b[0m"
        else
          empty
        end

      # Tool output (bash results)
      elif .type == "tool_result" then
        .output // empty

      else
        empty
      end
    '
}

push_changes() {
  local branch
  branch=$(git branch --show-current)

  # Check if there are changes to push
  if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git status --porcelain)" ]; then
    git add -A
    git commit -m "chore: ralph iteration ${ITERATION}" --no-verify 2>/dev/null || true
  fi

  # Push to remote, set upstream if needed
  if git rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
    git push
  else
    git push -u origin "${branch}"
  fi
}

main() {
  echo -e "${CYAN}ralph loop starting${RESET}"
  [ "$MAX_ITERATIONS" -gt 0 ] && echo -e "${DIM}max iterations: ${MAX_ITERATIONS}${RESET}"
  echo ""

  while true; do
    ITERATION=$((ITERATION + 1))

    echo -e "${CYAN}━━━ iteration ${ITERATION} ━━━${RESET}"
    echo ""

    run_ralph

    echo ""
    echo -e "${DIM}pushing changes...${RESET}"
    push_changes

    # Check iteration limit
    if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
      echo ""
      echo -e "${CYAN}completed ${ITERATION} iterations${RESET}"
      break
    fi

    echo ""
  done
}

main
