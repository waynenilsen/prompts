#!/usr/bin/env bash
# Common utilities for bootstrap scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

log() {
  echo -e "${CYAN}▶${RESET} $1"
}

success() {
  echo -e "${GREEN}✓${RESET} $1"
}

error() {
  echo -e "${RED}✗${RESET} $1" >&2
  exit 1
}

# Generate random port in range 50000-60000
random_port() {
  echo $((RANDOM % 10000 + 50000))
}

# Ensure we're in the project directory
ensure_project_dir() {
  if [ ! -f "package.json" ]; then
    error "Not in a project directory (package.json not found)"
  fi
}
