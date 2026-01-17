#!/usr/bin/env bash
#
# new-inner-loop.sh - Deterministically compose and run prompts based on ralph logic
#
# This script deterministically builds prompts using bash logic instead of
# relying on relative path resolution in Claude Max.

set -euo pipefail

# Debug: Script start
echo "[DEBUG] new-inner-loop.sh: Starting"

# Get absolute path to this script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR"
echo "[DEBUG] new-inner-loop.sh: SCRIPT_DIR=$SCRIPT_DIR"
echo "[DEBUG] new-inner-loop.sh: PROMPTS_DIR=$PROMPTS_DIR"

# Main execution
main() {
  echo "[DEBUG] new-inner-loop.sh: Entering main()"
  
  # Push any unpushed commits from previous iteration
  echo "[DEBUG] new-inner-loop.sh: Checking for unpushed commits..."
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    echo "[DEBUG] new-inner-loop.sh: LOCAL=$LOCAL"
    echo "[DEBUG] new-inner-loop.sh: REMOTE=$REMOTE"
    if [ "$LOCAL" != "$REMOTE" ]; then
      echo "[DEBUG] new-inner-loop.sh: Local and remote differ, attempting push..."
      if ! git push; then
        echo "[DEBUG] new-inner-loop.sh: Push failed, calling claude-wrapper"
        PUSH_FAIL_PROMPT="i cant run git push, we all push to main, i probably just have to get the last few commits on this branch"
        "$SCRIPT_DIR/claude-wrapper.sh" "$PUSH_FAIL_PROMPT"
        exit 0
      fi
      echo "[DEBUG] new-inner-loop.sh: Push succeeded"
    else
      echo "[DEBUG] new-inner-loop.sh: Local and remote are in sync"
    fi
  else
    echo "[DEBUG] new-inner-loop.sh: No upstream branch configured"
  fi

  # Actually execute git fetch and pull main
  echo "[DEBUG] new-inner-loop.sh: Running git fetch..."
  git fetch
  echo "[DEBUG] new-inner-loop.sh: Running git pull main..."
  git pull
  echo "[DEBUG] new-inner-loop.sh: Git fetch/pull completed"

  # Format the code - if formatting makes changes, add everything, commit, push, and exit
  echo "[DEBUG] new-inner-loop.sh: Running biome format..."
  bunx biome format --write .
  echo "[DEBUG] new-inner-loop.sh: Checking for formatting changes..."
  if ! git diff --quiet; then
    echo "[DEBUG] new-inner-loop.sh: Formatting changes detected, staging and committing..."
    git add -A
    git commit -m "chore: fix formatting"
    echo "[DEBUG] new-inner-loop.sh: Attempting to push formatting commit..."
    if ! git push; then
      echo "[DEBUG] new-inner-loop.sh: Push failed, calling claude-wrapper"
      PUSH_FAIL_PROMPT="i cant run git push, we all push to main, i probably just have to get the last few commits on this branch"
      "$SCRIPT_DIR/claude-wrapper.sh" "$PUSH_FAIL_PROMPT"
      exit 0
    fi
    echo "[DEBUG] new-inner-loop.sh: Formatting commit pushed successfully, exiting"
    exit 0
  else
    echo "[DEBUG] new-inner-loop.sh: No formatting changes detected"
  fi

  # Lint and fix - if linting makes changes, add everything, commit, push, and exit
  echo "[DEBUG] new-inner-loop.sh: Running biome lint..."
  bunx biome lint --unsafe --write .
  echo "[DEBUG] new-inner-loop.sh: Checking for linting changes..."
  if ! git diff --quiet; then
    echo "[DEBUG] new-inner-loop.sh: Linting changes detected, staging and committing..."
    git add -A
    git commit -m "chore: fix linting"
    echo "[DEBUG] new-inner-loop.sh: Attempting to push linting commit..."
    if ! git push; then
      echo "[DEBUG] new-inner-loop.sh: Push failed, calling claude-wrapper"
      PUSH_FAIL_PROMPT="i cant run git push, we all push to main, i probably just have to get the last few commits on this branch"
      "$SCRIPT_DIR/claude-wrapper.sh" "$PUSH_FAIL_PROMPT"
      exit 0
    fi
    echo "[DEBUG] new-inner-loop.sh: Linting commit pushed successfully, exiting"
    exit 0
  else
    echo "[DEBUG] new-inner-loop.sh: No linting changes detected"
  fi

  # Install dependencies and setup Prisma before running tests
  echo "[DEBUG] new-inner-loop.sh: Installing dependencies..."
  bun i
  echo "[DEBUG] new-inner-loop.sh: Generating Prisma client..."
  bunx prisma generate
  echo "[DEBUG] new-inner-loop.sh: Pushing Prisma schema to database..."
  bunx prisma db push --force-reset

  # Run unit tests - if they fail, call claude-wrapper to fix them
  echo "[DEBUG] new-inner-loop.sh: Running unit tests..."
  if ! bun run test; then
    echo "[DEBUG] new-inner-loop.sh: Unit tests failed, loading fixing-unit-tests.md and calling claude-wrapper"
    FIX_TESTS_PROMPT="$(cat "$PROMPTS_DIR/dev/fixing-unit-tests.md")"
    echo "[DEBUG] new-inner-loop.sh: Prompt loaded, length=${#FIX_TESTS_PROMPT} chars"
    "$SCRIPT_DIR/claude-wrapper.sh" "$FIX_TESTS_PROMPT"
    echo "[DEBUG] new-inner-loop.sh: claude-wrapper completed, exiting"
    exit 0
  else
    echo "[DEBUG] new-inner-loop.sh: Unit tests passed"
  fi

  # Run e2e tests - if they fail, call claude-wrapper to fix them
  echo "[DEBUG] new-inner-loop.sh: Running e2e tests..."
  if ! bun run test:e2e; then
    echo "[DEBUG] new-inner-loop.sh: E2E tests failed, loading e2e-troubleshooting.md and calling claude-wrapper"
    FIX_E2E_PROMPT="$(cat "$PROMPTS_DIR/dev/e2e-troubleshooting.md")"
    echo "[DEBUG] new-inner-loop.sh: Prompt loaded, length=${#FIX_E2E_PROMPT} chars"
    "$SCRIPT_DIR/claude-wrapper.sh" "$FIX_E2E_PROMPT"
    echo "[DEBUG] new-inner-loop.sh: claude-wrapper completed, exiting"
    exit 0
  else
    echo "[DEBUG] new-inner-loop.sh: E2E tests passed"
  fi
  
  # Step 1: Check git diff staged
  echo "[DEBUG] new-inner-loop.sh: Checking git diff staged..."
  if git diff --cached --quiet; then
    echo "[DEBUG] new-inner-loop.sh: Git staged is CLEAN, calling git-diff-staged-clean.sh"
    # If clean, compose and execute the prompt for the "if clean" branch
    "$SCRIPT_DIR/git-diff-staged-clean.sh"
    echo "[DEBUG] new-inner-loop.sh: git-diff-staged-clean.sh completed"
  else
    echo "[DEBUG] new-inner-loop.sh: Git staged is NOT CLEAN, calling git-diff-staged-not-clean.sh"
    # If not clean, handle the "if not clean" branch
    "$SCRIPT_DIR/git-diff-staged-not-clean.sh"
    echo "[DEBUG] new-inner-loop.sh: git-diff-staged-not-clean.sh completed"
  fi
}

main
