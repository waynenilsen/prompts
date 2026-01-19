#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: update.sh <target-dir>"
    exit 1
fi

TARGET_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$TARGET_DIR/prompts"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist"
    exit 1
fi

if [ ! -d "$DEST" ]; then
    echo "Error: Prompts directory '$DEST' does not exist. Use install.sh instead."
    exit 1
fi

# Function to check if an item should be excluded
should_exclude() {
    local name="$1"
    case "$name" in
        .git|.claude|.gitignore|AGENTS.md|CLAUDE.md|install.sh|update.sh|bootstrap-repo.sh|test-bootstrap-repo-output)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to update a file or directory
update_item() {
    local src_item="$1"
    local rel_path="$2"
    local dest_item="$DEST/$rel_path"
    local name="$(basename "$src_item")"
    
    if should_exclude "$name"; then
        return 0
    fi
    
    if [ -d "$src_item" ]; then
        # It's a directory - create if needed and recurse
        if [ ! -d "$dest_item" ]; then
            mkdir -p "$dest_item"
        fi
        
        # Recurse into directory
        for subitem in "$src_item"/* "$src_item"/.[!.]*; do
            [ -e "$subitem" ] || continue
            subname="$(basename "$subitem")"
            if [ "$subname" = "." ] || [ "$subname" = ".." ]; then
                continue
            fi
            update_item "$subitem" "$rel_path/$subname"
        done
    elif [ -f "$src_item" ]; then
        # It's a file - update if it exists, or create if it doesn't
        cp "$src_item" "$dest_item"
    fi
}

# Update all items from source
for item in "$SCRIPT_DIR"/* "$SCRIPT_DIR"/.[!.]*; do
    [ -e "$item" ] || continue
    name="$(basename "$item")"
    if [ "$name" = "." ] || [ "$name" = ".." ]; then
        continue
    fi
    
    if ! should_exclude "$name"; then
        update_item "$item" "$name"
    fi
done

echo "Prompts updated in $DEST"
