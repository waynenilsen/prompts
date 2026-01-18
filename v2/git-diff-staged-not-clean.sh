#!/usr/bin/env bash
#
# git-diff-staged-not-clean.sh - Handle "if not clean" branch of ralph
#
# This script handles the case when there are staged changes.
# It composes a prompt to continue working on the current ticket.
# Note: Preflight checks (formatting, linting, tests) are handled in new-inner-loop.sh

# Enable alias expansion in non-interactive shell
shopt -s expand_aliases

# Source no-guard-bashrc.sh to give node bun bla bla all tools to claude as well as to get the claude alias
[ -f ~/.no-guard-bashrc.sh ] && source ~/.no-guard-bashrc.sh

# Debug: Script start
echo "[DEBUG] git-diff-staged-not-clean.sh: Starting"

# Get absolute path to prompts directory using pushd/popd instead of cd
pushd "$(dirname "$0")" >/dev/null
SCRIPT_DIR="$(pwd)"
popd >/dev/null
PROMPTS_DIR="$SCRIPT_DIR"
echo "[DEBUG] git-diff-staged-not-clean.sh: SCRIPT_DIR=$SCRIPT_DIR"
echo "[DEBUG] git-diff-staged-not-clean.sh: PROMPTS_DIR=$PROMPTS_DIR"
echo "[DEBUG] git-diff-staged-not-clean.sh: Current directory=$(pwd)"

# Get next ticket from backlog
echo "[DEBUG] git-diff-staged-not-clean.sh: Getting next ticket from backlog..."
NEXT_TICKET_JSON=$("$SCRIPT_DIR/get-next-backlog-issue.sh" --json)
echo "[DEBUG] git-diff-staged-not-clean.sh: Next ticket JSON retrieved"

# Get staged diff to help identify the current ticket
echo "[DEBUG] git-diff-staged-not-clean.sh: Getting staged changes..."
STAGED_DIFF=$(git diff --cached)
echo "[DEBUG] git-diff-staged-not-clean.sh: Staged diff retrieved, length=${#STAGED_DIFF} chars"

# Check if we got a valid ticket
if [[ -n "$NEXT_TICKET_JSON" ]] && [[ "$NEXT_TICKET_JSON" != "{}" ]] && [[ "$(echo "$NEXT_TICKET_JSON" | jq -r '.number // empty')" != "" ]]; then
  ISSUE_NUMBER=$(echo "$NEXT_TICKET_JSON" | jq -r '.number')
  ISSUE_TITLE=$(echo "$NEXT_TICKET_JSON" | jq -r '.title')
  ISSUE_BODY=$(echo "$NEXT_TICKET_JSON" | jq -r '.body // "No description provided."')
  ISSUE_URL=$(echo "$NEXT_TICKET_JSON" | jq -r '.url')
  
  echo "[DEBUG] git-diff-staged-not-clean.sh: Found ticket #${ISSUE_NUMBER}: ${ISSUE_TITLE}"
  
  # Compose prompt to continue working on current ticket
  echo "[DEBUG] git-diff-staged-not-clean.sh: Composing prompt to continue ticket work..."
  COMPOSED_PROMPT=$({
    # Reference what-is-a-promptgram
    echo "ref [what-is-a-promptgram]"
    cat "$PROMPTS_DIR/promptgrams/what-is-a-promptgram.md"
    echo ""
    echo "begin"
    echo ""
    echo "CRITICAL RULE: Ralph works on EXACTLY ONE ticket per run. Once that ticket is complete, ralph MUST STOP. Do not work on another ticket. Do not create PRDs or ERDs. Ralph is DONE."
    echo ""
    echo "There are staged changes. These changes probably correspond to ticket #${ISSUE_NUMBER}: ${ISSUE_TITLE}"
    echo ""
    echo "Issue URL: ${ISSUE_URL}"
    echo ""
    echo "Issue Description:"
    echo "${ISSUE_BODY}"
    echo ""
    echo "Note: This may be a particularly tricky ticket. Check the ./notes folder for any recent notes that may be related to this issue."
    echo ""
    echo "Staged changes:"
    echo '```'
    echo "${STAGED_DIFF}"
    echo '```'
    echo ""
    echo "Continue working on this ticket. Use the staged changes above to understand the current state and continue from there."
    echo ""
    echo "ref [implement-ticket]"
    cat "$PROMPTS_DIR/dev/implement-ticket.md"
    echo ""
    echo "CRITICAL: After completing the current ticket, STOP. Do not work on another ticket. Ralph is DONE."
  })
else
  echo "[DEBUG] git-diff-staged-not-clean.sh: No ticket found in backlog, composing generic prompt..."
  
  # Fallback: no ticket found, but still have staged changes
  COMPOSED_PROMPT=$({
    # Reference what-is-a-promptgram
    echo "ref [what-is-a-promptgram]"
    cat "$PROMPTS_DIR/promptgrams/what-is-a-promptgram.md"
    echo ""
    echo "begin"
    echo ""
    echo "CRITICAL RULE: Ralph works on EXACTLY ONE ticket per run. Once that ticket is complete, ralph MUST STOP. Do not work on another ticket. Do not create PRDs or ERDs. Ralph is DONE."
    echo ""
    echo "There are staged changes but no ticket was found in the backlog. Use gh to check the tickets in the project to identify which ticket you're working on."
    echo "Use the staged changes below to figure out the context and continue working on the current ticket."
    echo ""
    echo "Note: This may be a particularly tricky ticket. Check the ./notes folder for any recent notes that may be related."
    echo ""
    echo "Staged changes:"
    echo '```'
    echo "${STAGED_DIFF}"
    echo '```'
    echo ""
    echo "ref [implement-ticket]"
    cat "$PROMPTS_DIR/dev/implement-ticket.md"
    echo ""
    echo "CRITICAL: After completing the current ticket, STOP. Do not work on another ticket. Ralph is DONE."
  })
fi

echo "[DEBUG] git-diff-staged-not-clean.sh: Prompt composed, length=${#COMPOSED_PROMPT} chars, calling claude-wrapper"
"$SCRIPT_DIR/claude-wrapper.sh" "$COMPOSED_PROMPT"
echo "[DEBUG] git-diff-staged-not-clean.sh: claude-wrapper completed, exiting"
exit 0
