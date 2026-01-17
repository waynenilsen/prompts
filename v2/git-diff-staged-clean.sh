#!/usr/bin/env bash
#
# git-diff-staged-clean.sh - Compose prompt body for "if clean" branch of ralph
#
# This script deterministically composes the prompt by reading referenced files
# with absolute paths and outputting the complete prompt text.

set -euo pipefail

# Debug: Script start
echo "[DEBUG] git-diff-staged-clean.sh: Starting"

# Get absolute path to prompts directory using pushd/popd instead of cd
pushd "$(dirname "$0")" >/dev/null
SCRIPT_DIR="$(pwd)"
popd >/dev/null
PROMPTS_DIR="$SCRIPT_DIR"
echo "[DEBUG] git-diff-staged-clean.sh: SCRIPT_DIR=$SCRIPT_DIR"
echo "[DEBUG] git-diff-staged-clean.sh: PROMPTS_DIR=$PROMPTS_DIR"
echo "[DEBUG] git-diff-staged-clean.sh: Current directory=$(pwd)"

# Check for next ticket in backlog
echo "[DEBUG] git-diff-staged-clean.sh: All checks passed, checking for next ticket..."
NEXT_TICKET_JSON=$("$SCRIPT_DIR/get-next-backlog-issue.sh" --json)
echo "[DEBUG] git-diff-staged-clean.sh: Next ticket JSON retrieved"

# Check if we got a valid ticket (not empty and not "{}")
if [[ -n "$NEXT_TICKET_JSON" ]] && [[ "$NEXT_TICKET_JSON" != "{}" ]] && [[ "$(echo "$NEXT_TICKET_JSON" | jq -r '.number // empty')" != "" ]]; then
  echo "[DEBUG] git-diff-staged-clean.sh: Ticket found, composing ticket work prompt..."
  ISSUE_NUMBER=$(echo "$NEXT_TICKET_JSON" | jq -r '.number')
  ISSUE_TITLE=$(echo "$NEXT_TICKET_JSON" | jq -r '.title')
  ISSUE_BODY=$(echo "$NEXT_TICKET_JSON" | jq -r '.body // "No description provided."')
  ISSUE_URL=$(echo "$NEXT_TICKET_JSON" | jq -r '.url')
  
  echo "[DEBUG] git-diff-staged-clean.sh: Issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}"
  
  # Compose prompt for working on ticket
  COMPOSED_PROMPT=$({
    # Reference what-is-a-promptgram
    echo "ref [what-is-a-promptgram]"
    cat "$PROMPTS_DIR/promptgrams/what-is-a-promptgram.md"
    echo ""
    echo "begin"
    echo ""
    echo "CRITICAL RULE: Ralph works on EXACTLY ONE ticket per run. Once that ticket is complete, ralph MUST STOP. Do not work on another ticket. Do not create PRDs or ERDs. Ralph is DONE."
    echo ""
    echo "Work on ticket #${ISSUE_NUMBER}: ${ISSUE_TITLE}"
    echo ""
    echo "Issue URL: ${ISSUE_URL}"
    echo ""
    echo "Issue Description:"
    echo "${ISSUE_BODY}"
    echo ""
    echo "ref [implement-ticket]"
    cat "$PROMPTS_DIR/dev/implement-ticket.md"
    echo ""
    echo "CRITICAL: After completing this ONE ticket, STOP. Do not work on another ticket. Do not continue. Ralph is DONE."
  })
  
  echo "[DEBUG] git-diff-staged-clean.sh: Prompt composed, length=${#COMPOSED_PROMPT} chars, calling claude-wrapper"
  "$SCRIPT_DIR/claude-wrapper.sh" "$COMPOSED_PROMPT"
  echo "[DEBUG] git-diff-staged-clean.sh: claude-wrapper completed, exiting"
  exit 0
else
  echo "[DEBUG] git-diff-staged-clean.sh: No tickets found, composing PRD/ERD creation prompt..."
  
  # Compose prompt for creating PRD/ERD
  COMPOSED_PROMPT=$({
    # Reference what-is-a-promptgram
    echo "ref [what-is-a-promptgram]"
    cat "$PROMPTS_DIR/promptgrams/what-is-a-promptgram.md"
    echo ""
    echo "begin"
    echo ""
    echo "There are no tickets in the backlog."
    echo ""
    echo "Read the roadmap ref [roadmap]"
    cat "$PROMPTS_DIR/roadmap/roadmap.md"
    echo ""
    echo "Identify the current phase and which features need PRDs"
    echo "Create the next PRD for a feature from the current roadmap phase ref [prd]"
    cat "$PROMPTS_DIR/product/prd.md"
    echo ""
    echo "Create the ERD to go with it ref [erd]"
    cat "$PROMPTS_DIR/dev/erd.md"
    echo ""
    echo "Create the tickets and add them to the project ref [create-tickets-from-erd]"
    cat "$PROMPTS_DIR/dev/create-tickets-from-erd.md"
    echo ""
    echo "Update the roadmap to link the new PRD"
    echo "Commit and push ref [conventional-commits]"
    cat "$PROMPTS_DIR/dev/conventional-commits.md"
    echo ""
    echo "CRITICAL: After creating tickets, STOP. Do not work on any tickets. Ralph is DONE."
  })
  
  echo "[DEBUG] git-diff-staged-clean.sh: Prompt composed, length=${#COMPOSED_PROMPT} chars, calling claude-wrapper"
  "$SCRIPT_DIR/claude-wrapper.sh" "$COMPOSED_PROMPT"
  echo "[DEBUG] git-diff-staged-clean.sh: claude-wrapper completed, exiting"
  exit 0
fi

echo "[DEBUG] git-diff-staged-clean.sh: Prompt composition completed"
