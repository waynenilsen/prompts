#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: install.sh <target-dir>"
    exit 1
fi

TARGET_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist"
    exit 1
fi

DEST="$TARGET_DIR/prompts"
mkdir -p "$DEST"

for item in "$SCRIPT_DIR"/*  "$SCRIPT_DIR"/.[!.]*; do
    [ -e "$item" ] || continue
    name="$(basename "$item")"
    case "$name" in
        .git|.claude|.gitignore|AGENTS.md|CLAUDE.md|install.sh|bootstrap-repo.sh|test-bootstrap-repo-output) continue ;;
    esac
    cp -r "$item" "$DEST/"
done

echo "Prompts installed to $DEST"
