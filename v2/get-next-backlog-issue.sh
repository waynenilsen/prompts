#!/usr/bin/env bash
#
# get-next-backlog-issue.sh - Get the next issue from open issues ordered by PRD and ticket number
#
# Usage:
#   ./scripts/get-next-backlog-issue.sh
#   ./scripts/get-next-backlog-issue.sh --json
#
# Outputs the issue number and title, or JSON if --json flag is used
#
# Ordering: Issues are ordered by [PRD-XXXX-TICKET-XXX] tags in titles:
#   - Lower PRD number = higher priority
#   - Within same PRD, lower ticket number = higher priority
#   - Issues without tags are sorted last

set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

# Parse flags
JSON_OUTPUT=false
if [[ "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=true
fi

# Get repo name from git remote for filtering
REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$REPO_URL" ]]; then
  echo -e "${RED}✗${RESET} Could not determine repository. Are you in a git repository?" >&2
  exit 1
fi

# Extract repo name
if [[ "$REPO_URL" =~ git@github.com:[^/]+/([^/]+)\.git ]]; then
  REPO="${BASH_REMATCH[1]}"
elif [[ "$REPO_URL" =~ https://github.com/[^/]+/([^/]+)\.git ]]; then
  REPO="${BASH_REMATCH[1]}"
elif [[ "$REPO_URL" =~ https://github.com/[^/]+/([^/]+) ]]; then
  REPO="${BASH_REMATCH[1]}"
else
  echo -e "${RED}✗${RESET} Could not parse repository URL: $REPO_URL" >&2
  exit 1
fi

# Get owner name for repo filtering
ACTUAL_OWNER=$(gh api user --jq '.login' 2>/dev/null || echo "waynenilsen")
REPO_FULL="$ACTUAL_OWNER/$REPO"

# Fetch ALL open issues (limit 10000 to ensure we don't miss any)
# Only fetch title and number for efficiency
ISSUES=$(gh issue list \
  --repo "$REPO_FULL" \
  --state open \
  --limit 10000 \
  --json number,title,state \
  2>/dev/null || echo '[]')

if [[ "$ISSUES" == "[]" ]] || [[ -z "$ISSUES" ]]; then
  # No open tickets - find the most recently completed PRD from closed tickets
  echo "[DEBUG] get-next-backlog-issue.sh: No open tickets, finding most recently completed PRD..." >&2
  
  CLOSED_ISSUES=$(gh issue list \
    --repo "$REPO_FULL" \
    --state closed \
    --limit 10000 \
    --json number,title \
    2>/dev/null || echo '[]')
  
  echo "[DEBUG] get-next-backlog-issue.sh: Repo: $REPO_FULL" >&2
  echo "[DEBUG] get-next-backlog-issue.sh: Closed issues count: $(echo "$CLOSED_ISSUES" | jq 'length')" >&2
  
  MOST_RECENT_PRD_NUMBER=""
  MOST_RECENT_PRD_FILE=""
  
  if [[ "$CLOSED_ISSUES" != "[]" ]] && [[ -n "$CLOSED_ISSUES" ]]; then
    echo "[DEBUG] get-next-backlog-issue.sh: Found closed issues, extracting PRD numbers..." >&2
    # Extract PRD numbers from closed ticket titles and find the highest one
    PRD_NUMBERS=$(echo "$CLOSED_ISSUES" | jq -r '
      .[] |
      select(.title | test("\\[PRD-\\d+-TICKET-\\d+\\]")) |
      .title | capture("\\[PRD-(?<prd>\\d+)-TICKET-\\d+\\]") | .prd | tonumber
    ' 2>/dev/null || echo "")
    
    if [[ -z "$PRD_NUMBERS" ]] || [[ "$PRD_NUMBERS" == "" ]]; then
      echo "[DEBUG] get-next-backlog-issue.sh: No PRD tags found in closed tickets" >&2
    else
      echo "[DEBUG] get-next-backlog-issue.sh: PRD numbers found: $(echo "$PRD_NUMBERS" | tr '\n' ' ')" >&2
      
      HIGHEST_PRD=$(echo "$PRD_NUMBERS" | sort -rn | head -1)
      
      echo "[DEBUG] get-next-backlog-issue.sh: Highest PRD found: '$HIGHEST_PRD'" >&2
      
      if [[ -n "$HIGHEST_PRD" ]] && [[ "$HIGHEST_PRD" != "null" ]] && [[ "$HIGHEST_PRD" != "" ]] && [[ "$HIGHEST_PRD" =~ ^[0-9]+$ ]]; then
        # Format as 4-digit zero-padded number
        PRD_NUMBER=$(printf "%04d" "$HIGHEST_PRD")
        MOST_RECENT_PRD_NUMBER="$PRD_NUMBER"
        
        # Look for the PRD file (optional - we return PRD number even if file doesn't exist)
        if [[ -d "./prd" ]]; then
          PRD_FILE=$(find ./prd -name "${PRD_NUMBER}-*.md" -type f 2>/dev/null | head -1)
          if [[ -n "$PRD_FILE" ]] && [[ -f "$PRD_FILE" ]]; then
            MOST_RECENT_PRD_FILE="$PRD_FILE"
            echo "[DEBUG] get-next-backlog-issue.sh: Found PRD file: $PRD_FILE" >&2
          else
            echo "[DEBUG] get-next-backlog-issue.sh: PRD file not found for PRD-$PRD_NUMBER (will return PRD number only)" >&2
          fi
        else
          echo "[DEBUG] get-next-backlog-issue.sh: ./prd/ directory does not exist (will return PRD number only)" >&2
        fi
      fi
    fi
  fi
  
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    if [[ -n "$MOST_RECENT_PRD_NUMBER" ]]; then
      # Return JSON with most recently completed PRD info
      jq -n \
        --arg prd_number "$MOST_RECENT_PRD_NUMBER" \
        --arg prd_file "$MOST_RECENT_PRD_FILE" \
        '{
          mostRecentCompletedPRD: {
            number: $prd_number,
            file: $prd_file
          }
        }'
    else
      echo "{}"
    fi
  else
    if [[ -n "$MOST_RECENT_PRD_NUMBER" ]]; then
      echo -e "${DIM}No open issues found${RESET}"
      echo -e "${DIM}Most recently completed PRD: PRD-${MOST_RECENT_PRD_NUMBER}${RESET}"
      if [[ -n "$MOST_RECENT_PRD_FILE" ]]; then
        echo -e "${DIM}PRD file: ${MOST_RECENT_PRD_FILE}${RESET}"
      fi
    else
      echo -e "${DIM}No open issues found${RESET}"
    fi
  fi
  exit 0
fi

# Parse and sort issues by PRD and ticket number
# Format: [PRD-0001-TICKET-001]
# Extract PRD number and ticket number, sort numerically
NEXT_ISSUE=$(echo "$ISSUES" | jq -r '
  .[] |
  # Extract PRD and ticket numbers from title tag [PRD-XXXX-TICKET-XXX]
  . as $issue |
  ($issue.title | capture("\\[PRD-(?<prd>\\d+)-TICKET-(?<ticket>\\d+)\\]") // {prd: "99999", ticket: "99999"}) |
  {
    number: $issue.number,
    title: $issue.title,
    prd: (.prd | tonumber),
    ticket: (.ticket | tonumber),
    hasTag: ($issue.title | test("\\[PRD-\\d+-TICKET-\\d+\\]"))
  }
' | jq -s '
  # Sort: tagged issues first (by PRD, then ticket), untagged issues last
  sort_by([.hasTag, .prd, .ticket] | map(if type == "boolean" then (if . then 0 else 1 end) else . end)) |
  .[0]
')

# Output result
if [[ "$NEXT_ISSUE" == "null" ]] || [[ -z "$NEXT_ISSUE" ]]; then
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "{}"
  else
    echo -e "${DIM}No issues found${RESET}"
  fi
  exit 0
fi

ISSUE_NUMBER=$(echo "$NEXT_ISSUE" | jq -r '.number')

ISSUE_DATA=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO_FULL" --json number,title,body,state,labels,assignees,createdAt,updatedAt,url,author)

if [[ "$JSON_OUTPUT" == "true" ]]; then
  echo "$ISSUE_DATA"
else
  TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
  BODY=$(echo "$ISSUE_DATA" | jq -r '.body // "No description provided."')
  STATE=$(echo "$ISSUE_DATA" | jq -r '.state')
  URL=$(echo "$ISSUE_DATA" | jq -r '.url')
  AUTHOR=$(echo "$ISSUE_DATA" | jq -r '.author.login')
  LABELS=$(echo "$ISSUE_DATA" | jq -r '.labels | map(.name) | join(", ") // ""')
  ASSIGNEES=$(echo "$ISSUE_DATA" | jq -r '.assignees | map(.login) | join(", ") // ""')

  echo -e "${GREEN}#${ISSUE_NUMBER}${RESET} ${TITLE}"
  echo -e "${DIM}${URL}${RESET}"
  echo ""
  echo -e "${DIM}State:${RESET} ${STATE}"
  [[ -n "$AUTHOR" ]] && echo -e "${DIM}Author:${RESET} ${AUTHOR}"
  [[ -n "$LABELS" ]] && echo -e "${DIM}Labels:${RESET} ${LABELS}"
  [[ -n "$ASSIGNEES" ]] && echo -e "${DIM}Assignees:${RESET} ${ASSIGNEES}"
  echo ""
  echo -e "${DIM}──────────────────────────────────────${RESET}"
  echo ""
  echo "$BODY"

  # Reminder about commit message format
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━ include Closes #${ISSUE_NUMBER} in your commit message and GitHub will automatically close the ticket and link the commit with the issue${RESET}"
fi
