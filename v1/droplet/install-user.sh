#!/usr/bin/env bash
#
# install-user.sh - User installation script for Ralph droplet
#
# Sets up the Ralph loop as a systemd user service
# Must be run as the non-root user
#

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "Error: This script must NOT be run as root"
    exit 1
fi

echo "Setting up Ralph loop for user: $(whoami)"

# Ensure we're in the home directory
cd "$HOME" || exit 1

# Install NVM (Node Version Manager)
if [ ! -d "$HOME/.nvm" ]; then
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    
    # Source NVM in current shell
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Add to bashrc if not already there
    if ! grep -q "NVM_DIR" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" <<'EOF'

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
    fi
    
    # Install latest LTS Node.js
    # Source bashrc in a way that doesn't fail on NVM's internal errors
    set +u  # Temporarily disable unbound variable check for NVM
    source "$HOME/.bashrc" || true
    nvm install --lts || true
    nvm use --lts || true
    nvm alias default node 2>/dev/null || true
    set -u  # Re-enable unbound variable check
else
    echo "NVM already installed"
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Install Bun if not already installed
if ! command -v bun &> /dev/null; then
    echo "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    # Bun installer should add to bashrc, but ensure it's there
    if ! grep -q ".bun/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    export PATH="$HOME/.bun/bin:$PATH"
else
    echo "Bun already installed"
fi